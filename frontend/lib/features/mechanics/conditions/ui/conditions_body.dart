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
import '../../../catalog/ui/catalog_appearance.dart';
import '../../../catalog/ui/open_catalog_detail.dart';
import '../../../dm_tools/resources/data/resource_models.dart';
import '../../../dm_tools/resources/data/resources_api.dart';
import '../../data/styled_mechanics_record.dart';
import '../../mechanics_icons.dart';
import '../../ui/styled_mechanics_ui.dart';
import 'condition_list_item_card.dart';
import 'condition_sheet.dart';

class ConditionsBody extends StatefulWidget {
  const ConditionsBody({super.key, required this.auth});

  final AuthController auth;

  @override
  State<ConditionsBody> createState() => _ConditionsBodyState();
}

class _ConditionsBodyState extends State<ConditionsBody> {
  final _api = CatalogApi();
  final _resourcesApi = ResourcesApi();
  bool _loading = true;
  String? _error;
  List<CatalogItem> _items = const [];
  List<ResourceFile> _resourceFiles = const [];

  Future<String?> _token() => widget.auth.requireAccessToken();

  @override
  void initState() {
    super.initState();
    _reload();
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
      items.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );
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

  Future<void> _open(CatalogItem item) async {
    final deleted = await openCatalogRecordDetail(
      context: context,
      auth: widget.auth,
      kindApiValue: item.kind.apiValue,
      itemId: item.id,
    );
    if (deleted == true || mounted) await _reload();
  }

  Future<void> _delete(CatalogItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete condition?'),
        content: Text('Delete “${item.name}”? This cannot be undone.'),
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
        itemId: item.id,
      );
      await _reload();
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
        if (_loading)
          const Center(child: CircularProgressIndicator())
        else if (_error != null)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_error!, textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  FilledButton(onPressed: _reload, child: const Text('Retry')),
                ],
              ),
            ),
          )
        else if (_items.isEmpty)
          RefreshIndicator(
            onRefresh: _reload,
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: ConstrainedBox(
                    constraints:
                        BoxConstraints(minHeight: constraints.maxHeight),
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 24, 24, 100),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'No conditions yet',
                              style: Theme.of(context).textTheme.headlineSmall,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Tap + to add your first condition.',
                              textAlign: TextAlign.center,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(color: scheme.onSurfaceVariant),
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
        else
          RefreshIndicator(
            onRefresh: _reload,
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              itemCount: _items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final item = _items[index];
                final record = StyledMechanicsRecord.fromCatalogPayload(
                  name: item.name,
                  payload: item.payload,
                );
                return ConditionListItemCard(
                  record: record,
                  onTap: () => _open(item),
                  onDelete: widget.auth.canMutateCatalog
                      ? () => _delete(item)
                      : null,
                );
              },
            ),
          ),
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
          if (widget.auth.canMutateCatalog) ...[
            IconButton(
              tooltip: 'Edit',
              icon: const Icon(Icons.edit_outlined),
              onPressed: _edit,
            ),
            IconButton(
              tooltip: 'Delete',
              icon: const Icon(Icons.delete_outline),
              onPressed: _delete,
            ),
          ],
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
