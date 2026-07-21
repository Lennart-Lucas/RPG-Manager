import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../../core/ui/markdown_form_field.dart';
import '../../../auth/data/auth_api.dart';
import '../../../auth/state/auth_controller.dart';
import '../../../catalog/data/catalog_api.dart';
import '../../../catalog/data/catalog_kind.dart';
import '../../../catalog/data/catalog_models.dart';
import '../../../export/card_export_pdf.dart';
import '../../../export/card_export_theme.dart';
import '../../../export/card_pdf_export_sheet.dart';
import '../../../shell/app_page.dart';
import '../../../shell/shell_page_app_bar.dart';
import '../../player_options_icons.dart';
import '../data/feat_list_derived_data.dart';
import '../data/feat_list_filters.dart';
import '../data/feat_model.dart';
import 'feat_detail_page.dart';
import 'feat_form_sheet.dart';
import 'feat_record_list_view.dart';
import 'feats_filter_strip.dart';

class FeatsBody extends StatefulWidget {
  const FeatsBody({super.key, required this.auth});

  final AuthController auth;

  @override
  State<FeatsBody> createState() => _FeatsBodyState();
}

class _FeatsBodyState extends State<FeatsBody>
    with SingleTickerProviderStateMixin {
  final _api = CatalogApi();
  final _searchController = TextEditingController();

  late final AnimationController _filterPanelAnimation;

  bool _loading = true;
  String? _error;
  List<CatalogItem> _items = const [];

  FeatsListFilter _filter = FeatsListFilter.empty;
  FeatsSortMode _sortMode = FeatsSortMode.alphabetical;
  bool _selectionMode = false;
  final Set<String> _selectedItemIds = <String>{};

  static String get _pageKey => AppPage.feats.name;

  @override
  void initState() {
    super.initState();
    _filterPanelAnimation = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed ||
            status == AnimationStatus.dismissed) {
          _installShellAppBar();
        }
      });
    _searchController.addListener(_onSearchChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _installShellAppBar();
    });
    _reload();
  }

  @override
  void dispose() {
    _filterPanelAnimation.dispose();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    ShellPageAppBarStore.instance.clearPageBar(_pageKey);
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {});
    _installShellAppBar();
  }

  bool get _hasActiveFilters =>
      _filter.hasAny || _searchController.text.trim().isNotEmpty;

  void _installShellAppBar() {
    if (!mounted) return;
    final scheme = Theme.of(context).colorScheme;
    final active = _hasActiveFilters;
    final filtersOpen = !_filterPanelAnimation.isDismissed &&
        _filterPanelAnimation.status != AnimationStatus.reverse;

    ShellPageAppBarStore.instance.setPageBar(
      _pageKey,
      ShellPageAppBarData(
        actions: [
          IconButton(
            tooltip: 'Clear filters',
            icon: Icon(
              Icons.filter_list_off,
              color: active ? scheme.primary : null,
            ),
            onPressed: active ? _clearFilters : null,
          ),
          IconButton(
            tooltip: 'Filters',
            icon: Icon(
              filtersOpen ? Icons.filter_list : Icons.filter_list_outlined,
              color: active || filtersOpen ? scheme.primary : null,
            ),
            onPressed: _toggleFilters,
          ),
          IconButton(
            tooltip: _selectionMode ? 'Exit selection mode' : 'Select feats',
            icon: Icon(
              _selectionMode
                  ? Icons.checklist_rtl_rounded
                  : Icons.checklist_outlined,
              color: _selectionMode ? scheme.primary : null,
            ),
            onPressed: () => _setSelectionMode(!_selectionMode),
          ),
        ],
      ),
    );
  }

  void _setSelectionMode(bool enabled) {
    setState(() {
      _selectionMode = enabled;
      if (!enabled) _selectedItemIds.clear();
    });
    _installShellAppBar();
  }

  void _toggleItemSelection(String key) {
    setState(() {
      if (_selectedItemIds.contains(key)) {
        _selectedItemIds.remove(key);
      } else {
        _selectedItemIds.add(key);
      }
    });
  }

  void _selectAllFilteredItems(List<FeatListEntry> displayEntries) {
    final ids = <String>{};
    for (final e in displayEntries) {
      final entry = e.catalogEntry;
      if (entry != null) ids.add(entry.key);
    }
    if (ids.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No feats match the current filters or search.'),
        ),
      );
      return;
    }
    setState(() => _selectedItemIds.addAll(ids));
  }

  void _deselectAllSelectedItems() {
    setState(_selectedItemIds.clear);
  }

  Future<Uint8List?> _composeSelectedFeatsPdfBytes({
    required CardExportThemeSelection cardExportTheme,
    required int cardsPerRow,
    required int cardsPerColumn,
    required double pageMargin,
    required double cardGap,
  }) async {
    final derived = _derived;
    final selected = derived.allEntries
        .where((e) => _selectedItemIds.contains(e.key))
        .toList(growable: false);
    selected.sort(
      (a, b) =>
          a.entry.name.toLowerCase().compareTo(b.entry.name.toLowerCase()),
    );
    if (selected.isEmpty) return null;

    final theme = themeForCardExport(context, cardExportTheme);
    final images = <Uint8List>[];
    for (final entry in selected) {
      if (!mounted) return null;
      images.addAll(
        await rasterizeFeatCards(
          context: context,
          feat: entry.entry,
          theme: theme,
        ),
      );
    }
    if (!mounted) return null;
    return buildCardsPdf(
      pngBytesList: images,
      title: 'Selected feat cards',
      includeCoverPage: false,
      cardsPerRow: cardsPerRow,
      cardsPerColumn: cardsPerColumn,
      pageMargin: pageMargin,
      cardGap: cardGap,
    );
  }

  Future<void> _exportSelectedFeatsToPdf({
    required CardExportThemeSelection cardExportTheme,
    required int cardsPerRow,
    required int cardsPerColumn,
    required double pageMargin,
    required double cardGap,
  }) async {
    try {
      final pdf = await _composeSelectedFeatsPdfBytes(
        cardExportTheme: cardExportTheme,
        cardsPerRow: cardsPerRow,
        cardsPerColumn: cardsPerColumn,
        pageMargin: pageMargin,
        cardGap: cardGap,
      );
      if (pdf == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No feats selected to export.')),
        );
        return;
      }
      if (!mounted) return;
      await presentCardExportPdf(pdf);
    } catch (e, st) {
      debugPrint('Feat export failed: $e\n$st');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $e')),
      );
    }
  }

  Future<void> _openFeatCardExportSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        final viewInsets = MediaQuery.viewInsetsOf(sheetContext);
        final maxH = MediaQuery.sizeOf(sheetContext).height * 0.92;
        return Padding(
          padding: EdgeInsets.only(bottom: viewInsets.bottom),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxH),
            child: CardPdfExportSheet(
              key: const ValueKey('feat_card_pdf_export_sheet'),
              sheetTitle: 'Export feat cards',
              hasSelection: _selectedItemIds.isNotEmpty,
              composePdf: ({
                required CardExportThemeSelection cardExportTheme,
                required int cardsPerRow,
                required int cardsPerColumn,
                required double pageMargin,
                required double cardGap,
              }) =>
                  _composeSelectedFeatsPdfBytes(
                cardExportTheme: cardExportTheme,
                cardsPerRow: cardsPerRow,
                cardsPerColumn: cardsPerColumn,
                pageMargin: pageMargin,
                cardGap: cardGap,
              ),
              onGenerate: ({
                required CardExportThemeSelection cardExportTheme,
                required int cardsPerRow,
                required int cardsPerColumn,
                required double pageMargin,
                required double cardGap,
              }) {
                Navigator.of(sheetContext).pop();
                _exportSelectedFeatsToPdf(
                  cardExportTheme: cardExportTheme,
                  cardsPerRow: cardsPerRow,
                  cardsPerColumn: cardsPerColumn,
                  pageMargin: pageMargin,
                  cardGap: cardGap,
                );
              },
            ),
          ),
        );
      },
    );
  }

  Future<String?> _token() => widget.auth.requireAccessToken();

  FeatRecord? _featFromCatalog(CatalogItem item) {
    try {
      return FeatRecord.fromCatalogPayload(
        name: item.name,
        payload: item.payload,
        id: FeatRecord.slugify(item.name),
      );
    } catch (_) {
      return null;
    }
  }

  List<FeatCatalogEntry> get _featEntries {
    final out = <FeatCatalogEntry>[];
    for (final item in _items) {
      final entry = _featFromCatalog(item);
      if (entry == null) continue;
      out.add(
        FeatCatalogEntry(
          item: item,
          entry: entry.copyWith(name: item.name),
        ),
      );
    }
    return out;
  }

  FeatsDerivedViewData get _derived {
    return deriveFeatsViewData(
      featEntries: _featEntries,
      filter: _filter,
      sortMode: _sortMode,
    );
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final token = await _token();
      if (token == null) {
        throw AuthApiException('Not authenticated');
      }
      final items = await _api.list(token, CatalogKind.feats);
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } on AuthApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load feats';
        _loading = false;
      });
    }
  }

  Future<List<CatalogLinkTarget>> _searchLinks(
    String token,
    String query,
  ) async {
    var nameQuery = query;
    String? kindPrefix;
    final slash = query.lastIndexOf('/');
    if (slash >= 0) {
      kindPrefix = query.substring(0, slash).trim().toLowerCase();
      nameQuery = query.substring(slash + 1);
    }
    try {
      final results = await _api.search(token, query: nameQuery);
      if (kindPrefix == null || kindPrefix.isEmpty) return results;
      return results
          .where((item) => item.kind.toLowerCase().startsWith(kindPrefix!))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<List<CatalogLinkTarget>> _loadAutoLinkTargets(String token) async {
    try {
      final results = await Future.wait([
        _api.list(token, CatalogKind.conditions),
        _api.list(token, CatalogKind.damageTypes),
      ]);
      return [
        for (final item in results[0])
          CatalogLinkTarget(
            id: item.id,
            kind: item.kind.apiValue,
            name: item.name,
          ),
        for (final item in results[1])
          CatalogLinkTarget(
            id: item.id,
            kind: item.kind.apiValue,
            name: item.name,
          ),
      ];
    } catch (_) {
      return const [];
    }
  }

  Future<void> _create() async {
    try {
      final token = await _token();
      if (token == null || !mounted) return;
      final entry = await showFeatFormSheet(
        context,
        searchLinks: (query) => _searchLinks(token, query),
        loadAutoLinkTargets: () => _loadAutoLinkTargets(token),
      );
      if (entry == null || !mounted) return;
      await _api.create(
        accessToken: token,
        kind: CatalogKind.feats,
        name: entry.name,
        payload: entry.toJson(),
      );
      await _reload();
    } on AuthApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not create feat')),
      );
    }
  }

  Future<void> _edit(CatalogItem item) async {
    try {
      final token = await _token();
      if (token == null || !mounted) return;
      final existing = _featFromCatalog(item);
      final entry = await showFeatFormSheet(
        context,
        initial: existing,
        searchLinks: (query) => _searchLinks(token, query),
        loadAutoLinkTargets: () => _loadAutoLinkTargets(token),
      );
      if (entry == null || !mounted) return;
      await _api.update(
        accessToken: token,
        kind: CatalogKind.feats,
        itemId: item.id,
        name: entry.name,
        payload: entry.toJson(),
      );
      await _reload();
    } on AuthApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not update feat')),
      );
    }
  }

  Future<void> _openDetail(FeatCatalogEntry entry) async {
    final deleted = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => FeatDetailPage(
          auth: widget.auth,
          item: entry.item,
          entry: entry.entry,
        ),
      ),
    );
    if (deleted == true || mounted) {
      await _reload();
    }
  }

  void _toggleFilters() {
    if (_filterPanelAnimation.isDismissed ||
        _filterPanelAnimation.status == AnimationStatus.reverse) {
      _filterPanelAnimation.forward();
    } else {
      _filterPanelAnimation.reverse();
    }
    _installShellAppBar();
  }

  void _clearFilters() {
    setState(() {
      _filter = FeatsListFilter.empty;
      _sortMode = FeatsSortMode.alphabetical;
      _searchController.clear();
    });
    _installShellAppBar();
  }

  Future<void> _pickSortMode() async {
    final result = await showModalBottomSheet<FeatsSortMode>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final mode in FeatsSortMode.values)
                ListTile(
                  leading: Icon(mode.icon),
                  title: Text(mode.label),
                  selected: mode == _sortMode,
                  onTap: () => Navigator.pop(ctx, mode),
                ),
            ],
          ),
        );
      },
    );
    if (result == null || !mounted) return;
    setState(() => _sortMode = result);
    _installShellAppBar();
  }

  Future<void> _pickHasRequirement() async {
    final result = await showModalBottomSheet<FeatRequirementFilter>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final option in FeatRequirementFilter.values)
                ListTile(
                  title: Text(option.label),
                  selected: option == _filter.hasRequirement,
                  onTap: () => Navigator.pop(ctx, option),
                ),
            ],
          ),
        );
      },
    );
    if (result == null || !mounted) return;
    setState(() {
      _filter = _filter.copyWith(hasRequirement: result);
    });
    _installShellAppBar();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final derived = _loading || _error != null ? null : _derived;
    final displayEntries = derived == null
        ? const <FeatListEntry>[]
        : filterFeatListEntriesBySearch(
            derived.entries,
            _searchController.text,
          );

    return Stack(
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: Center(
              child: Opacity(
                opacity: 0.08,
                child: Icon(
                  featsPageIcon,
                  size: 440,
                  color: scheme.onSurface,
                ),
              ),
            ),
          ),
        ),
        Column(
          children: [
            SizeTransition(
              sizeFactor: _filterPanelAnimation,
              alignment: Alignment.topCenter,
              child: FeatsFilterStrip(
                sectionBottomPadding: 12,
                searchController: _searchController,
                sortModeSummary: _sortMode.label,
                hasRequirementSummary: _filter.hasRequirement.label,
                onSortModeTap: _pickSortMode,
                onHasRequirementTap: _pickHasRequirement,
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(_error!, textAlign: TextAlign.center),
                                const SizedBox(height: 12),
                                FilledButton(
                                  onPressed: _reload,
                                  child: const Text('Retry'),
                                ),
                              ],
                            ),
                          ),
                        )
                      : derived!.allEntries.isEmpty
                          ? RefreshIndicator(
                              onRefresh: _reload,
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  return SingleChildScrollView(
                                    physics:
                                        const AlwaysScrollableScrollPhysics(),
                                    child: ConstrainedBox(
                                      constraints: BoxConstraints(
                                        minHeight: constraints.maxHeight,
                                      ),
                                      child: Center(
                                        child: Padding(
                                          padding: const EdgeInsets.fromLTRB(
                                            24,
                                            24,
                                            24,
                                            100,
                                          ),
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                'No feats yet',
                                                textAlign: TextAlign.center,
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .headlineSmall,
                                              ),
                                              const SizedBox(height: 8),
                                              Text(
                                                'Tap + to add your first feat.',
                                                textAlign: TextAlign.center,
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodyMedium
                                                    ?.copyWith(
                                                      color: scheme
                                                          .onSurfaceVariant,
                                                    ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            )
                          : FeatRecordListView(
                              totalItems: derived.allEntries.length,
                              entries: displayEntries,
                              selectedItemIds: _selectedItemIds,
                              selectionEmphasis: _selectionMode,
                              hasActiveSearch:
                                  _searchController.text.trim().isNotEmpty,
                              bottomPadding: _selectionMode ? 16 : 88,
                              onRefresh: _reload,
                              onItemPrimaryTap: (entry) {
                                if (_selectionMode) {
                                  _toggleItemSelection(entry.key);
                                } else {
                                  _openDetail(entry);
                                }
                              },
                              onItemLongPress: _selectionMode
                                  ? null
                                  : (entry) => _edit(entry.item),
                            ),
            ),
            if (_selectionMode)
              Material(
                color: scheme.surfaceContainerHigh,
                elevation: 6,
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${_selectedItemIds.length} selected',
                            style: Theme.of(context).textTheme.titleSmall,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Select all filtered feats',
                          onPressed: () =>
                              _selectAllFilteredItems(displayEntries),
                          icon: const Icon(Icons.playlist_add_check),
                        ),
                        IconButton(
                          tooltip: 'Deselect all',
                          onPressed: _deselectAllSelectedItems,
                          icon: const Icon(Icons.clear_all),
                        ),
                        FilledButton.icon(
                          onPressed: _openFeatCardExportSheet,
                          icon: const Icon(
                            Icons.picture_as_pdf_outlined,
                            size: 18,
                          ),
                          label: const Text('Export'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
        if (!_selectionMode)
          Positioned(
            right: 20,
            bottom: 20,
            child: FloatingActionButton(
              onPressed: _create,
              backgroundColor: scheme.primary,
              foregroundColor: scheme.onPrimary,
              child: const Icon(Icons.add),
            ),
          ),
      ],
    );
  }
}
