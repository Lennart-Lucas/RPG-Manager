import 'package:flutter/material.dart';

import '../../../../core/offline/offline_marker.dart';
import '../../../../core/ui/simple_card_rich_text.dart';
import '../../../auth/data/auth_api.dart';
import '../../../auth/state/auth_controller.dart';
import '../../../catalog/data/catalog_api.dart';
import '../../../catalog/data/catalog_auto_link.dart';
import '../../../catalog/data/catalog_kind.dart';
import '../../../catalog/data/catalog_models.dart';
import '../../../catalog/ui/open_catalog_detail.dart';
import '../../world_icons.dart';
import '../data/location_model.dart';
import 'location_form_sheet.dart';
import 'location_overview_box.dart';
import 'location_tree_view.dart';

class LocationDetailPage extends StatefulWidget {
  const LocationDetailPage({
    super.key,
    required this.auth,
    required this.item,
  });

  final AuthController auth;
  final CatalogItem item;

  @override
  State<LocationDetailPage> createState() => _LocationDetailPageState();
}

class _LocationDetailPageState extends State<LocationDetailPage> {
  static const _wideBreakpoint = 900.0;

  final _api = CatalogApi();
  late CatalogItem _item = widget.item;
  List<CatalogItem> _all = const [];
  List<CatalogItem> _breadcrumb = const [];

  Future<String?> _token() => widget.auth.requireAccessToken();

  LocationRecord get _record => LocationRecord.fromCatalogPayload(
        name: _item.name,
        payload: _item.payload,
      );

  List<LocationAncestorRow> get _ancestorRows {
    return [
      for (final item in _breadcrumb)
        LocationAncestorRow(
          typeLabel: LocationRecord.fromCatalogPayload(
            name: item.name,
            payload: item.payload,
          ).type.label,
          item: item,
        ),
    ];
  }

  @override
  void initState() {
    super.initState();
    _loadLocations();
  }

  Future<void> _loadLocations() async {
    try {
      final token = await _token();
      if (token == null) return;
      final all = await _api.list(token, CatalogKind.locations);
      if (!mounted) return;
      setState(() {
        _all = all;
        _breadcrumb = _buildBreadcrumb(all);
      });
    } catch (_) {}
  }

  List<CatalogItem> _buildBreadcrumb(List<CatalogItem> all) {
    final byId = {for (final i in all) i.id: i};
    final chain = <CatalogItem>[];
    var current = _record.parentId;
    final seen = <int>{};
    while (current != null && !seen.contains(current)) {
      seen.add(current);
      final parent = byId[current];
      if (parent == null) break;
      chain.insert(0, parent);
      current = LocationRecord.fromCatalogPayload(
        name: parent.name,
        payload: parent.payload,
      ).parentId;
    }
    return chain;
  }

  Future<void> _edit() async {
    try {
      final token = await _token();
      if (token == null || !mounted) return;
      if (_all.isEmpty) {
        _all = await _api.list(token, CatalogKind.locations);
      }
      if (!mounted) return;
      final updatedRecord = await showLocationFormSheet(
        context,
        initial: _record,
        allLocations: _all,
        editingItemId: _item.id,
        searchLinks: (q) => searchCatalogLinkTargets(_api, token, q),
        loadAutoLinkTargets: () =>
            loadConditionDamageAutoLinkTargets(_api, token),
      );
      if (updatedRecord == null || !mounted) return;
      final updated = await _api.update(
        accessToken: token,
        kind: CatalogKind.locations,
        itemId: _item.id,
        name: updatedRecord.name,
        payload: updatedRecord.toJson(),
      );
      if (!mounted) return;
      setState(() => _item = updated);
      await _loadLocations();
    } on AuthApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not update location')),
      );
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete location?'),
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
        kind: CatalogKind.locations,
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
        const SnackBar(content: Text('Could not delete location')),
      );
    }
  }

  Future<void> _openLocation(CatalogItem item) async {
    await openCatalogRecordDetail(
      context: context,
      auth: widget.auth,
      kindApiValue: CatalogKind.locations.apiValue,
      itemId: item.id,
    );
    if (mounted) await _loadLocations();
  }

  Widget _articleTitle(LocationRecord record) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _item.name,
          style: textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        if (record.aliases.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            record.aliases.join(', '),
            style: textTheme.titleMedium?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ],
    );
  }

  Widget _description(LocationRecord record) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    if (record.description.trim().isEmpty) {
      return Text(
        'No description yet.',
        style: textTheme.bodyLarge?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      );
    }
    return SimpleCardRichText(
      content: record.description,
      onWikiLinkTap: (kind, name) => openCatalogWikiLink(
        context: context,
        auth: widget.auth,
        kindApiValue: kind,
        name: name,
      ),
    );
  }

  Widget _overviewBox() {
    return LocationOverviewBox(
      record: _record,
      ancestors: _ancestorRows,
      onAncestorTap: _openLocation,
    );
  }

  Widget _subLocations() {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Sub-locations', style: textTheme.titleMedium),
        const SizedBox(height: 8),
        LocationTreeView(
          locations: _all,
          rootParentId: _item.id,
          emptyLabel: 'No sub-locations.',
          onTap: _openLocation,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final record = _record;

    return Scaffold(
      appBar: AppBar(
        title: Text(_item.name.trim().isEmpty ? 'Location' : _item.name),
        actions: [
          const OfflineAppBarMarker(),
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
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: Center(
                child: Opacity(
                  opacity: 0.08,
                  child: Icon(atlasPageIcon, size: 440, color: scheme.onSurface),
                ),
              ),
            ),
          ),
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= _wideBreakpoint;
              return ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  if (wide)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _articleTitle(record),
                              const SizedBox(height: 20),
                              _description(record),
                              const SizedBox(height: 28),
                              _subLocations(),
                            ],
                          ),
                        ),
                        const SizedBox(width: 24),
                        SizedBox(
                          width: LocationOverviewBox.preferredWidth,
                          child: _overviewBox(),
                        ),
                      ],
                    )
                  else ...[
                    _articleTitle(record),
                    const SizedBox(height: 16),
                    _overviewBox(),
                    const SizedBox(height: 20),
                    _description(record),
                    const SizedBox(height: 28),
                    _subLocations(),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
