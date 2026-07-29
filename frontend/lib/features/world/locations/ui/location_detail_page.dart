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
  final _api = CatalogApi();
  late CatalogItem _item = widget.item;
  List<CatalogItem> _all = const [];
  List<CatalogItem> _breadcrumb = const [];

  Future<String?> _token() => widget.auth.requireAccessToken();

  LocationRecord get _record => LocationRecord.fromCatalogPayload(
        name: _item.name,
        payload: _item.payload,
      );

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

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final record = _record;
    final infobox = record.filledInfoboxFields;

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
          ListView(
            padding: const EdgeInsets.all(24),
            children: [
              if (_breadcrumb.isNotEmpty) ...[
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    for (var i = 0; i < _breadcrumb.length; i++) ...[
                      if (i > 0)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Icon(
                            Icons.chevron_right,
                            size: 16,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      InkWell(
                        onTap: () => openCatalogRecordDetail(
                          context: context,
                          auth: widget.auth,
                          kindApiValue: CatalogKind.locations.apiValue,
                          itemId: _breadcrumb[i].id,
                        ),
                        child: Text(
                          _breadcrumb[i].name,
                          style: textTheme.bodyMedium?.copyWith(
                            color: scheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
              ],
              Text(_item.name, style: textTheme.headlineSmall),
              const SizedBox(height: 4),
              Chip(label: Text(record.type.label)),
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 720;
                  final overview = infobox.isEmpty
                      ? const SizedBox.shrink()
                      : Container(
                          width: wide ? 280 : double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: scheme.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: scheme.outlineVariant),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Overview',
                                style: textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 10),
                              for (final row in infobox) ...[
                                Text(
                                  row.$1,
                                  style: textTheme.labelMedium?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(row.$2, style: textTheme.bodyMedium),
                                const SizedBox(height: 10),
                              ],
                            ],
                          ),
                        );
                  final body = record.description.trim().isEmpty
                      ? Text(
                          'No description yet.',
                          style: textTheme.bodyLarge?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        )
                      : SimpleCardRichText(
                          content: record.description,
                          onWikiLinkTap: (kind, name) => openCatalogWikiLink(
                            context: context,
                            auth: widget.auth,
                            kindApiValue: kind,
                            name: name,
                          ),
                        );
                  if (!wide) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        overview,
                        if (infobox.isNotEmpty) const SizedBox(height: 20),
                        body,
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: body),
                      if (infobox.isNotEmpty) ...[
                        const SizedBox(width: 20),
                        overview,
                      ],
                    ],
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
