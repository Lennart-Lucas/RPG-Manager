import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../core/offline/offline_marker.dart';
import '../../../../core/ui/mtg_card_rules_text_fit.dart';
import '../../../auth/data/auth_api.dart';
import '../../../auth/state/auth_controller.dart';
import '../../../catalog/data/catalog_api.dart';
import '../../../catalog/data/catalog_auto_link.dart';
import '../../../catalog/data/catalog_kind.dart';
import '../../../catalog/data/catalog_models.dart';
import '../../../catalog/data/catalog_wiki_resolve.dart';
import '../../../catalog/ui/catalog_appearance.dart';
import '../../../catalog/ui/open_catalog_detail.dart';
import '../../../dm_tools/resources/data/resource_models.dart';
import '../../../dm_tools/resources/data/resources_api.dart';
import '../../../export/card_export_pdf.dart';
import '../../../export/card_export_theme.dart';
import '../../../export/card_pdf_export_sheet.dart';
import '../../../export/card_png_export_present.dart';
import '../../../shell/app_page.dart';
import '../../../shell/shell_page_app_bar.dart';
import '../../data/styled_mechanics_record.dart';
import '../../mechanics_icons.dart';
import '../../ui/styled_mechanics_ui.dart';
import '../data/condition_list_derived_data.dart';
import 'condition_record_list_view.dart';
import 'condition_sheet.dart';

class ConditionsBody extends StatefulWidget {
  const ConditionsBody({super.key, required this.auth});

  final AuthController auth;

  @override
  State<ConditionsBody> createState() => _ConditionsBodyState();
}

class _ConditionsBodyState extends State<ConditionsBody>
    with SingleTickerProviderStateMixin {
  final _api = CatalogApi();
  final _resourcesApi = ResourcesApi();
  final _searchController = TextEditingController();

  late final AnimationController _filterPanelAnimation;

  bool _loading = true;
  String? _error;
  List<CatalogItem> _items = const [];
  List<ResourceFile> _resourceFiles = const [];

  bool _selectionMode = false;
  final Set<String> _selectedItemIds = <String>{};

  static String get _pageKey => AppPage.conditions.name;

  Future<String?> _token() => widget.auth.requireAccessToken();

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

  bool get _hasActiveFilters => _searchController.text.trim().isNotEmpty;

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
            tooltip: 'Clear search',
            icon: Icon(
              Icons.filter_list_off,
              color: active ? scheme.primary : null,
            ),
            onPressed: active ? _clearFilters : null,
          ),
          IconButton(
            tooltip: 'Search',
            icon: Icon(
              filtersOpen ? Icons.search : Icons.search_outlined,
              color: active || filtersOpen ? scheme.primary : null,
            ),
            onPressed: _toggleFilters,
          ),
          IconButton(
            tooltip: _selectionMode ? 'Exit selection mode' : 'Select conditions',
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

  void _selectAllFilteredItems(List<ConditionListEntry> displayEntries) {
    final ids = <String>{};
    for (final e in displayEntries) {
      final entry = e.catalogEntry;
      if (entry != null) ids.add(entry.key);
    }
    if (ids.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No conditions match the current search.'),
        ),
      );
      return;
    }
    setState(() => _selectedItemIds.addAll(ids));
  }

  void _deselectAllSelectedItems() {
    setState(_selectedItemIds.clear);
  }

  List<ConditionCatalogEntry> get _conditionEntries {
    return [
      for (final item in _items)
        ConditionCatalogEntry(
          item: item,
          entry: StyledMechanicsRecord.fromCatalogPayload(
            name: item.name,
            payload: item.payload,
          ),
        ),
    ];
  }

  ConditionsDerivedViewData get _derived {
    return deriveConditionsViewData(conditionEntries: _conditionEntries);
  }

  Future<Uint8List?> _composeSelectedPdfBytes({
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
        await rasterizeConditionCards(
          context: context,
          record: entry.entry,
          theme: theme,
          resolveWikiLinkLabel: (kind, id) => resolveCatalogWikiLinkLabel(
            auth: widget.auth,
            kindApiValue: kind,
            target: id,
          ),
        ),
      );
    }
    if (!mounted) return null;
    return buildCardsPdf(
      pngBytesList: images,
      title: 'Selected condition cards',
      includeCoverPage: false,
      cardsPerRow: cardsPerRow,
      cardsPerColumn: cardsPerColumn,
      pageMargin: pageMargin,
      cardGap: cardGap,
    );
  }

  Future<void> _exportSelectedToPdf({
    required CardExportThemeSelection cardExportTheme,
    required int cardsPerRow,
    required int cardsPerColumn,
    required double pageMargin,
    required double cardGap,
  }) async {
    try {
      final pdf = await _composeSelectedPdfBytes(
        cardExportTheme: cardExportTheme,
        cardsPerRow: cardsPerRow,
        cardsPerColumn: cardsPerColumn,
        pageMargin: pageMargin,
        cardGap: cardGap,
      );
      if (pdf == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No conditions selected to export.')),
        );
        return;
      }
      if (!mounted) return;
      await presentCardExportPdf(pdf);
    } catch (e, st) {
      debugPrint('Condition export failed: $e\n$st');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $e')),
      );
    }
  }

  Future<void> _openCardExportSheet() async {
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
              key: const ValueKey('condition_card_pdf_export_sheet'),
              sheetTitle: 'Export condition cards',
              hasSelection: _selectedItemIds.isNotEmpty,
              composePdf: ({
                required CardExportThemeSelection cardExportTheme,
                required int cardsPerRow,
                required int cardsPerColumn,
                required double pageMargin,
                required double cardGap,
              }) =>
                  _composeSelectedPdfBytes(
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
                _exportSelectedToPdf(
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

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final token = await _token();
      if (token == null) throw AuthApiException('Not authenticated');
      final items = await _api.list(token, CatalogKind.conditions);
      List<ResourceFile> files = const [];
      try {
        files = await _resourcesApi.listFiles(token);
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _items = items;
        _resourceFiles = files;
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
        _error = 'Could not load conditions';
        _loading = false;
      });
    }
  }

  Future<void> _create() async {
    try {
      final token = await _token();
      if (token == null || !mounted) return;
      final record = await showStyledMechanicsFormSheet(
        context,
        singularLabel: 'condition',
        fallbackIcon: conditionsPageIcon,
        defaultIconKey: 'monitor_heart',
        resourceFiles: _resourceFiles,
        appearanceIcons: kConditionAppearanceIcons,
        appearancePickerTitle: 'Condition icon & color',
        searchLinks: (q) => searchCatalogLinkTargets(_api, token, q),
        loadAutoLinkTargets: () =>
            loadConditionDamageAutoLinkTargets(_api, token),
      );
      if (record == null || !mounted) return;
      await _api.create(
        accessToken: token,
        kind: CatalogKind.conditions,
        name: record.name,
        payload: record.toJson(),
      );
      await _reload();
    } on AuthApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not create condition')),
      );
    }
  }

  Future<void> _edit(CatalogItem item) async {
    try {
      final token = await _token();
      if (token == null || !mounted) return;
      final initial = StyledMechanicsRecord.fromCatalogPayload(
        name: item.name,
        payload: item.payload,
      );
      final record = await showStyledMechanicsFormSheet(
        context,
        singularLabel: 'condition',
        fallbackIcon: conditionsPageIcon,
        defaultIconKey: 'monitor_heart',
        initial: initial,
        resourceFiles: _resourceFiles,
        appearanceIcons: kConditionAppearanceIcons,
        appearancePickerTitle: 'Condition icon & color',
        searchLinks: (q) => searchCatalogLinkTargets(_api, token, q),
        loadAutoLinkTargets: () =>
            loadConditionDamageAutoLinkTargets(_api, token),
      );
      if (record == null || !mounted) return;
      await _api.update(
        accessToken: token,
        kind: CatalogKind.conditions,
        itemId: item.id,
        name: record.name,
        payload: record.toJson(),
      );
      await _reload();
    } on AuthApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not update condition')),
      );
    }
  }

  Future<void> _openDetail(ConditionCatalogEntry entry) async {
    final deleted = await openCatalogRecordDetail(
      context: context,
      auth: widget.auth,
      kindApiValue: entry.item.kind.apiValue,
      itemId: entry.item.id,
    );
    if (deleted == true || mounted) await _reload();
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
      _searchController.clear();
    });
    _installShellAppBar();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final derived = _loading || _error != null ? null : _derived;
    final displayEntries = derived == null
        ? const <ConditionListEntry>[]
        : filterConditionListEntriesBySearch(
            derived.entries,
            _searchController.text,
          );
    final hasSearch = _searchController.text.trim().isNotEmpty;
    final barColor =
        theme.appBarTheme.backgroundColor ?? theme.scaffoldBackgroundColor;

    return Stack(
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: Center(
              child: Opacity(
                opacity: 0.08,
                child: Icon(
                  conditionsPageIcon,
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
              child: Material(
                color: barColor,
                elevation: 1,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      labelText: 'Search',
                      hintText: 'Name or description',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: hasSearch
                          ? IconButton(
                              tooltip: 'Clear search',
                              icon: const Icon(Icons.close),
                              onPressed: _searchController.clear,
                            )
                          : null,
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                    textInputAction: TextInputAction.search,
                  ),
                ),
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
                                                'No conditions yet',
                                                textAlign: TextAlign.center,
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .headlineSmall,
                                              ),
                                              const SizedBox(height: 8),
                                              Text(
                                                widget.auth.canMutateCatalog
                                                    ? 'Tap + to add your first condition.'
                                                    : 'No conditions yet.',
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
                          : ConditionRecordListView(
                              totalItems: derived.allEntries.length,
                              entries: displayEntries,
                              selectedItemIds: _selectedItemIds,
                              selectionEmphasis: _selectionMode,
                              hasActiveSearch: hasSearch,
                              bottomPadding: _selectionMode ? 16 : 88,
                              onRefresh: _reload,
                              onItemPrimaryTap: (entry) {
                                if (_selectionMode) {
                                  _toggleItemSelection(entry.key);
                                } else {
                                  _openDetail(entry);
                                }
                              },
                              onItemLongPress:
                                  _selectionMode || !widget.auth.canMutateCatalog
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
                          tooltip: 'Select all filtered conditions',
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
                          onPressed: _openCardExportSheet,
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
          if (widget.auth.canMutateCatalog)
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

class ConditionDetailPage extends StatefulWidget {
  const ConditionDetailPage({
    super.key,
    required this.auth,
    required this.item,
  });

  final AuthController auth;
  final CatalogItem item;

  @override
  State<ConditionDetailPage> createState() => _ConditionDetailPageState();
}

class _ConditionDetailPageState extends State<ConditionDetailPage> {
  final _api = CatalogApi();
  final _resourcesApi = ResourcesApi();

  late CatalogItem _item = widget.item;
  List<ResourceFile> _resourceFiles = const [];
  String? _sourceFileName;
  bool _exportingPng = false;

  Future<String?> _token() => widget.auth.requireAccessToken();

  StyledMechanicsRecord get _record => StyledMechanicsRecord.fromCatalogPayload(
        name: _item.name,
        payload: _item.payload,
      );

  bool _isDesktopPlatform() {
    final platform = defaultTargetPlatform;
    return platform == TargetPlatform.windows ||
        platform == TargetPlatform.macOS ||
        platform == TargetPlatform.linux;
  }

  @override
  void initState() {
    super.initState();
    _loadResources();
  }

  Future<void> _loadResources() async {
    try {
      final token = await _token();
      if (token == null) return;
      final files = await _resourcesApi.listFiles(token);
      if (!mounted) return;
      String? sourceName;
      final sourceId = _record.sourceFileId;
      if (sourceId != null) {
        for (final f in files) {
          if (f.id == sourceId) {
            sourceName = f.name;
            break;
          }
        }
      }
      setState(() {
        _resourceFiles = files;
        _sourceFileName = sourceName;
      });
    } catch (_) {}
  }

  Future<void> _edit() async {
    try {
      final token = await _token();
      if (token == null || !mounted) return;
      if (_resourceFiles.isEmpty) {
        try {
          _resourceFiles = await _resourcesApi.listFiles(token);
        } catch (_) {}
      }
      if (!mounted) return;
      final updatedRecord = await showStyledMechanicsFormSheet(
        context,
        singularLabel: 'condition',
        fallbackIcon: conditionsPageIcon,
        defaultIconKey: 'monitor_heart',
        initial: _record,
        resourceFiles: _resourceFiles,
        appearanceIcons: kConditionAppearanceIcons,
        appearancePickerTitle: 'Condition icon & color',
        searchLinks: (q) => searchCatalogLinkTargets(_api, token, q),
        loadAutoLinkTargets: () =>
            loadConditionDamageAutoLinkTargets(_api, token),
      );
      if (updatedRecord == null || !mounted) return;
      final updated = await _api.update(
        accessToken: token,
        kind: CatalogKind.conditions,
        itemId: _item.id,
        name: updatedRecord.name,
        payload: updatedRecord.toJson(),
      );
      if (!mounted) return;
      setState(() => _item = updated);
      await _loadResources();
    } on AuthApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not update condition')),
      );
    }
  }

  Future<void> _exportCardPng() async {
    if (_exportingPng) return;
    setState(() => _exportingPng = true);
    try {
      final bytes = await rasterizeConditionCard(
        context: context,
        record: _record,
        theme: Theme.of(context),
        resolveWikiLinkLabel: (kind, id) => resolveCatalogWikiLinkLabel(
          auth: widget.auth,
          kindApiValue: kind,
          target: id,
        ),
      );
      if (!mounted) return;
      await presentCardPngExport(
        bytes,
        '${cardExportSafeBaseName(_record.name)}.png',
      );
    } catch (e, st) {
      debugPrint('Condition card PNG export failed: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save image: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _exportingPng = false);
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete condition?'),
        content: Text('Delete “${_item.name}”? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      final token = await _token();
      if (token == null) return;
      await _api.delete(
        accessToken: token,
        kind: CatalogKind.conditions,
        itemId: _item.id,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on AuthApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not delete condition')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final record = _record;
    final accent = record.resolvedColor(fallback: scheme.primary);
    final icon = record.resolvedIcon(fallback: conditionsPageIcon);
    final desktopScale = _isDesktopPlatform() ? 1.25 : 1.0;
    final topSpacing = _isDesktopPlatform() ? 48.0 : 0.0;
    final hasSource = record.sourceFileId != null ||
        record.sourcePage != null ||
        (_sourceFileName?.isNotEmpty ?? false);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          record.name.trim().isEmpty ? 'Condition' : record.name,
        ),
        actions: [
          const OfflineAppBarMarker(),
          if (widget.auth.canMutateCatalog)
            IconButton(
              tooltip: 'Edit',
              icon: const Icon(Icons.edit_outlined),
              onPressed: _edit,
            ),
          IconButton(
            tooltip: 'Save as PNG',
            icon: const Icon(Icons.image_outlined),
            onPressed: _exportingPng ? null : _exportCardPng,
          ),
          if (widget.auth.canMutateCatalog)
            IconButton(
              tooltip: 'Delete',
              icon: const Icon(Icons.delete_outline),
              onPressed: _delete,
            ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: Center(
                child: Opacity(
                  opacity: 0.08,
                  child: catalogAppearanceIconWidget(
                    icon,
                    size: 440,
                    color: accent,
                  ),
                ),
              ),
            ),
          ),
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: EdgeInsets.only(top: topSpacing),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _CardPagesWrap(
                      cards: buildConditionSheets(
                        record,
                        cardScale: desktopScale,
                        maxFontSize: kMtgCardRulesMaxFontSize * desktopScale,
                        onWikiLinkTap: (kind, id) => openCatalogWikiLink(
                          context: context,
                          auth: widget.auth,
                          kindApiValue: kind,
                          target: id,
                        ),
                        resolveWikiLinkLabel: (kind, id) =>
                            resolveCatalogWikiLinkLabel(
                          auth: widget.auth,
                          kindApiValue: kind,
                          target: id,
                        ),
                      ),
                      scaleFactor: desktopScale,
                    ),
                    if (hasSource) ...[
                      const SizedBox(height: 12),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 760),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: scheme.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: scheme.outlineVariant),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Sources',
                                  style:
                                      Theme.of(context).textTheme.titleMedium,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '${_sourceFileName ?? 'Resource ${record.sourceFileId}'}'
                                  '${record.sourcePage != null ? ' · p. ${record.sourcePage}' : ''}',
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CardPagesWrap extends StatelessWidget {
  final List<Widget> cards;
  final double scaleFactor;

  const _CardPagesWrap({required this.cards, this.scaleFactor = 1.0});

  @override
  Widget build(BuildContext context) {
    if (cards.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, constraints) {
        final targetCardWidth = 360.0 * scaleFactor;
        final canFitTwo = constraints.maxWidth >= (targetCardWidth * 2) + 12;
        final cardWidth = canFitTwo
            ? targetCardWidth
            : constraints.maxWidth.clamp(0.0, targetCardWidth).toDouble();
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          alignment: WrapAlignment.center,
          children: [
            for (final card in cards)
              SizedBox(
                width: cardWidth,
                child: card,
              ),
          ],
        );
      },
    );
  }
}
