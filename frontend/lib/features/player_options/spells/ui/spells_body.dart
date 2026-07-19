import 'package:flutter/material.dart';

import '../../../../core/ui/markdown_form_field.dart';
import '../../../../core/ui/multi_picklist_sheet.dart';
import '../../../auth/data/auth_api.dart';
import '../../../auth/state/auth_controller.dart';
import '../../../catalog/data/catalog_api.dart';
import '../../../catalog/data/catalog_kind.dart';
import '../../../catalog/data/catalog_models.dart';
import '../../../dm_tools/resources/data/resource_models.dart';
import '../../../dm_tools/resources/data/resources_api.dart';
import '../../../shell/app_page.dart';
import '../../../shell/shell_page_app_bar.dart';
import '../../classes/data/class_model.dart';
import '../../player_options_icons.dart';
import '../data/spell_list_derived_data.dart';
import '../data/spell_list_filters.dart';
import '../data/spell_model.dart';
import 'spell_detail_page.dart';
import 'spell_form_sheet.dart';
import 'spell_record_list_view.dart';
import 'spells_filter_strip.dart';

class SpellsBody extends StatefulWidget {
  const SpellsBody({super.key, required this.auth});

  final AuthController auth;

  @override
  State<SpellsBody> createState() => _SpellsBodyState();
}

class _SpellsBodyState extends State<SpellsBody>
    with SingleTickerProviderStateMixin {
  final _api = CatalogApi();
  final _resourcesApi = ResourcesApi();
  final _searchController = TextEditingController();

  late final AnimationController _filterPanelAnimation;

  bool _loading = true;
  String? _error;
  List<CatalogItem> _items = const [];
  List<CatalogItem> _casters = const [];
  List<CatalogItem> _spellTags = const [];
  List<CatalogItem> _conditions = const [];
  List<CatalogItem> _damageTypes = const [];
  List<ResourceFile> _files = const [];

  SpellsListFilter _filter = SpellsListFilter.empty;
  SpellsSortMode _sortMode = SpellsSortMode.alphabetical;

  static String get _pageKey => AppPage.spells.name;

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
        ],
      ),
    );
  }

  Future<String?> _token() => widget.auth.requireAccessToken();

  Spell? _spellFromItem(CatalogItem item) {
    final payload = item.payload;
    if (payload == null) {
      return Spell(
        id: Spell.slugify(item.name),
        name: item.name,
        level: 0,
        school: SpellSchool.evocation,
        castingTime: const CastingTime.action(),
        range: const SpellRange.self(),
        components: const SpellComponents(
          verbal: false,
          somatic: false,
          material: false,
        ),
        duration: const SpellDuration.instantaneous(),
        classIds: const [],
        description: '',
      );
    }
    try {
      return Spell.fromJson(payload);
    } catch (_) {
      return null;
    }
  }

  List<SpellCatalogEntry> get _spellEntries {
    final out = <SpellCatalogEntry>[];
    for (final item in _items) {
      final spell = _spellFromItem(item);
      if (spell == null) continue;
      out.add(
        SpellCatalogEntry(
          item: item,
          spell: spell.copyWith(name: item.name),
        ),
      );
    }
    return out;
  }

  SpellsDerivedViewData get _derived {
    return deriveSpellsViewData(
      spellEntries: _spellEntries,
      casterClasses: _casters,
      spellTags: _spellTags,
      damageTypes: _damageTypes,
      conditions: _conditions,
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
      final results = await Future.wait([
        _api.list(token, CatalogKind.spells),
        _api.list(token, CatalogKind.classes),
        _api.list(token, CatalogKind.spellTags),
        _api.list(token, CatalogKind.conditions),
        _api.list(token, CatalogKind.damageTypes),
      ]);
      final classItems = results[1];
      final casters = classItems.where((item) {
        return ClassRecord.fromCatalogPayload(
          name: item.name,
          payload: item.payload,
        ).isCaster;
      }).toList();

      var files = const <ResourceFile>[];
      try {
        files = await _resourcesApi.listFiles(token);
      } on AuthApiException {
        // Non-DM users cannot list resources.
      } catch (_) {}

      if (!mounted) return;
      setState(() {
        _items = results[0];
        _casters = casters;
        _spellTags = results[2];
        _conditions = results[3];
        _damageTypes = results[4];
        _files = files;
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
        _error = 'Could not load spells';
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
      return [
        for (final item in _conditions)
          CatalogLinkTarget(
            id: item.id,
            kind: item.kind.apiValue,
            name: item.name,
          ),
        for (final item in _damageTypes)
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
      if (token == null) return;
      if (!mounted) return;
      final spell = await showSpellFormSheet(
        context,
        casterClasses: _casters,
        spellTags: _spellTags,
        resourceFiles: _files,
        searchLinks: (query) => _searchLinks(token, query),
        loadAutoLinkTargets: () => _loadAutoLinkTargets(token),
        aiIntegrationEnabled: widget.auth.user?.aiIntegration ?? false,
      );
      if (spell == null || !mounted) return;
      await _api.create(
        accessToken: token,
        kind: CatalogKind.spells,
        name: spell.name,
        payload: spell.toJson(),
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
        const SnackBar(content: Text('Could not create spell')),
      );
    }
  }

  Future<void> _edit(CatalogItem item) async {
    try {
      final token = await _token();
      if (token == null) return;
      if (!mounted) return;
      final existing = _spellFromItem(item);
      final spell = await showSpellFormSheet(
        context,
        initial: existing,
        casterClasses: _casters,
        spellTags: _spellTags,
        resourceFiles: _files,
        searchLinks: (query) => _searchLinks(token, query),
        loadAutoLinkTargets: () => _loadAutoLinkTargets(token),
        aiIntegrationEnabled: widget.auth.user?.aiIntegration ?? false,
      );
      if (spell == null || !mounted) return;
      await _api.update(
        accessToken: token,
        kind: CatalogKind.spells,
        itemId: item.id,
        name: spell.name,
        payload: spell.toJson(),
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
        const SnackBar(content: Text('Could not update spell')),
      );
    }
  }

  Future<void> _openDetail(SpellCatalogEntry entry) async {
    final derived = _derived;
    final classNames = derived.classNamesBySpellKey[entry.key] ?? const [];
    final tagEntries = derived.tagEntriesBySpellKey[entry.key] ?? const [];
    String? sourceName;
    final fileId = entry.spell.sourceFileId;
    if (fileId != null) {
      for (final f in _files) {
        if (f.id == fileId) {
          sourceName = f.name;
          break;
        }
      }
    }

    final deleted = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => SpellDetailPage(
          auth: widget.auth,
          item: entry.item,
          spell: entry.spell,
          classNames: classNames,
          tagNames: tagEntries.map((e) => e.name).toList(),
          sourceFileName: sourceName,
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
      _filter = SpellsListFilter.empty;
      _sortMode = SpellsSortMode.alphabetical;
      _searchController.clear();
    });
    _installShellAppBar();
  }

  String _summaryForSet(
    Set<String> selected,
    List<PicklistOption> options, {
    String empty = 'Any',
  }) {
    if (selected.isEmpty) return empty;
    final labels = <String>[];
    for (final opt in options) {
      if (selected.contains(opt.id)) labels.add(opt.label);
    }
    if (labels.isEmpty) return empty;
    return labels.join(', ');
  }

  Future<void> _pickMulti({
    required String title,
    required List<PicklistOption> options,
    required Set<String> selected,
    required void Function(Set<String> next) onDone,
  }) async {
    final result = await showMultiPicklistSheet(
      context,
      title: title,
      options: options,
      selected: selected,
    );
    if (result == null || !mounted) return;
    setState(() => onDone(result));
    _installShellAppBar();
  }

  Future<void> _pickSortMode() async {
    final result = await showModalBottomSheet<SpellsSortMode>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final mode in SpellsSortMode.values)
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

  Future<void> _pickConcentration() async {
    final result = await showModalBottomSheet<SpellsConcentrationFilter>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('Any'),
                selected:
                    _filter.concentrationFilter == SpellsConcentrationFilter.any,
                onTap: () =>
                    Navigator.pop(ctx, SpellsConcentrationFilter.any),
              ),
              ListTile(
                title: const Text('No concentration'),
                selected: _filter.concentrationFilter ==
                    SpellsConcentrationFilter.withoutConcentration,
                onTap: () => Navigator.pop(
                  ctx,
                  SpellsConcentrationFilter.withoutConcentration,
                ),
              ),
              ListTile(
                title: const Text('Concentration'),
                selected: _filter.concentrationFilter ==
                    SpellsConcentrationFilter.withConcentration,
                onTap: () => Navigator.pop(
                  ctx,
                  SpellsConcentrationFilter.withConcentration,
                ),
              ),
            ],
          ),
        );
      },
    );
    if (result == null || !mounted) return;
    setState(() {
      _filter = _filter.copyWith(concentrationFilter: result);
    });
    _installShellAppBar();
  }

  String get _concentrationSummary {
    return switch (_filter.concentrationFilter) {
      SpellsConcentrationFilter.any => 'Any',
      SpellsConcentrationFilter.withoutConcentration => 'No concentration',
      SpellsConcentrationFilter.withConcentration => 'Concentration',
    };
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final derived = _loading || _error != null ? null : _derived;
    final displayEntries = derived == null
        ? const <SpellListEntry>[]
        : filterSpellListEntriesBySearch(
            derived.entries,
            _searchController.text,
          );
    final schoolOptions = schoolPicklistOptions();
    final levelOptions = levelPicklistOptions();
    final castingOptions = castingTypePicklistOptions();
    final classOptions = catalogPicklistOptions([
      for (final c in _casters) (id: '${c.id}', name: c.name),
    ]);
    final tagOptions = catalogPicklistOptions([
      for (final t in _spellTags) (id: '${t.id}', name: t.name),
    ]);
    final conditionOptions = catalogPicklistOptions([
      for (final c in _conditions) (id: '${c.id}', name: c.name),
    ]);
    final damageOptions = catalogPicklistOptions([
      for (final d in _damageTypes) (id: '${d.id}', name: d.name),
    ]);

    return Stack(
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: Center(
              child: Opacity(
                opacity: 0.08,
                child: Icon(
                  spellsPageIcon,
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
              child: SpellsFilterStrip(
                sectionBottomPadding: 12,
                spellSearchController: _searchController,
                sortModeSummary: _sortMode.label,
                schoolSummary: _summaryForSet(
                  _filter.selectedSchoolCodes,
                  schoolOptions,
                ),
                levelSummary: _summaryForSet(
                  _filter.selectedLevelCodes,
                  levelOptions,
                ),
                spellTagsSummary: _summaryForSet(
                  _filter.selectedTagIds,
                  tagOptions,
                ),
                classesSummary: _summaryForSet(
                  _filter.selectedClassIds,
                  classOptions,
                ),
                damageTypesSummary: _summaryForSet(
                  _filter.selectedDamageTypeIds,
                  damageOptions,
                ),
                conditionsSummary: _summaryForSet(
                  _filter.selectedConditionIds,
                  conditionOptions,
                ),
                castingTypeSummary: _summaryForSet(
                  _filter.selectedCastingTypeCodes,
                  castingOptions,
                ),
                concentrationSummary: _concentrationSummary,
                onSortModeTap: _pickSortMode,
                onSchoolTap: () => _pickMulti(
                  title: 'School',
                  options: schoolOptions,
                  selected: _filter.selectedSchoolCodes,
                  onDone: (next) {
                    _filter = _filter.copyWith(selectedSchoolCodes: next);
                  },
                ),
                onLevelTap: () => _pickMulti(
                  title: 'Level',
                  options: levelOptions,
                  selected: _filter.selectedLevelCodes,
                  onDone: (next) {
                    _filter = _filter.copyWith(selectedLevelCodes: next);
                  },
                ),
                onSpellTagsTap: () => _pickMulti(
                  title: 'Spell tags',
                  options: tagOptions,
                  selected: _filter.selectedTagIds,
                  onDone: (next) {
                    _filter = _filter.copyWith(selectedTagIds: next);
                  },
                ),
                onClassesTap: () => _pickMulti(
                  title: 'Classes',
                  options: classOptions,
                  selected: _filter.selectedClassIds,
                  onDone: (next) {
                    _filter = _filter.copyWith(selectedClassIds: next);
                  },
                ),
                onDamageTypesTap: () => _pickMulti(
                  title: 'Damage types',
                  options: damageOptions,
                  selected: _filter.selectedDamageTypeIds,
                  onDone: (next) {
                    _filter = _filter.copyWith(selectedDamageTypeIds: next);
                  },
                ),
                onConditionsTap: () => _pickMulti(
                  title: 'Conditions',
                  options: conditionOptions,
                  selected: _filter.selectedConditionIds,
                  onDone: (next) {
                    _filter = _filter.copyWith(selectedConditionIds: next);
                  },
                ),
                onCastingTypeTap: () => _pickMulti(
                  title: 'Casting type',
                  options: castingOptions,
                  selected: _filter.selectedCastingTypeCodes,
                  onDone: (next) {
                    _filter =
                        _filter.copyWith(selectedCastingTypeCodes: next);
                  },
                ),
                onConcentrationTap: _pickConcentration,
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
                                                'No spells yet',
                                                textAlign: TextAlign.center,
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .headlineSmall,
                                              ),
                                              const SizedBox(height: 8),
                                              Text(
                                                'Tap + to add your first spell.',
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
                          : SpellRecordListView(
                              totalSpells: derived.allEntries.length,
                              entries: displayEntries,
                              classNamesBySpellKey:
                                  derived.classNamesBySpellKey,
                              tagEntriesBySpellKey:
                                  derived.tagEntriesBySpellKey,
                              hasActiveSearch:
                                  _searchController.text.trim().isNotEmpty,
                              onRefresh: _reload,
                              onSpellPrimaryTap: _openDetail,
                              onSpellLongPress: (entry) => _edit(entry.item),
                            ),
            ),
          ],
        ),
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
