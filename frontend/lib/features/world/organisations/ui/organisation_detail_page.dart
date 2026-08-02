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
import '../data/organisation_model.dart';
import 'organisation_form_sheet.dart';
import 'organisation_tree_view.dart';

class OrganisationDetailPage extends StatefulWidget {
  const OrganisationDetailPage({
    super.key,
    required this.auth,
    required this.item,
  });

  final AuthController auth;
  final CatalogItem item;

  @override
  State<OrganisationDetailPage> createState() => _OrganisationDetailPageState();
}

class _OrganisationDetailPageState extends State<OrganisationDetailPage> {
  final _api = CatalogApi();
  late CatalogItem _item = widget.item;
  Map<int, String> _characterNames = const {};
  List<CatalogItem> _all = const [];
  List<CatalogItem> _breadcrumb = const [];

  Future<String?> _token() => widget.auth.requireAccessToken();

  OrganisationRecord get _record => OrganisationRecord.fromCatalogPayload(
        name: _item.name,
        payload: _item.payload,
      );

  @override
  void initState() {
    super.initState();
    _loadRelated();
  }

  Future<void> _loadRelated() async {
    try {
      final token = await _token();
      if (token == null) return;
      final results = await Future.wait([
        _api.list(token, CatalogKind.characters),
        _api.list(token, CatalogKind.organisations),
      ]);
      if (!mounted) return;
      final chars = results[0];
      final orgs = results[1];
      setState(() {
        _characterNames = {for (final c in chars) c.id: c.name};
        _all = orgs;
        _breadcrumb = _buildBreadcrumb(orgs);
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
      current = OrganisationRecord.fromCatalogPayload(
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
      if (_characterNames.isEmpty || _all.isEmpty) await _loadRelated();
      if (!mounted) return;
      final updatedRecord = await showOrganisationFormSheet(
        context,
        initial: _record,
        characterNames: _characterNames,
        allOrganisations: _all,
        editingItemId: _item.id,
        searchLinks: (q) => searchCatalogLinkTargets(_api, token, q),
        loadAutoLinkTargets: () =>
            loadConditionDamageAutoLinkTargets(_api, token),
      );
      if (updatedRecord == null || !mounted) return;
      final updated = await _api.update(
        accessToken: token,
        kind: CatalogKind.organisations,
        itemId: _item.id,
        name: updatedRecord.name,
        payload: updatedRecord.toJson(),
      );
      if (!mounted) return;
      setState(() => _item = updated);
      await _loadRelated();
    } on AuthApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not update organisation')),
      );
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete organisation?'),
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
        kind: CatalogKind.organisations,
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
        const SnackBar(content: Text('Could not delete organisation')),
      );
    }
  }

  Future<void> _openOrganisation(CatalogItem item) async {
    await openCatalogRecordDetail(
      context: context,
      auth: widget.auth,
      kindApiValue: CatalogKind.organisations.apiValue,
      itemId: item.id,
    );
    if (mounted) await _loadRelated();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final record = _record;

    return Scaffold(
      appBar: AppBar(
        title: Text(_item.name.trim().isEmpty ? 'Organisation' : _item.name),
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
                  child: Icon(
                    organisationsPageIcon,
                    size: 440,
                    color: scheme.onSurface,
                  ),
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
                        onTap: () => _openOrganisation(_breadcrumb[i]),
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
              Text(
                'Organisation',
                style: textTheme.titleMedium?.copyWith(
                  color: scheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (record.memberIds.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text('Members', style: textTheme.titleSmall),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final id in record.memberIds)
                      ActionChip(
                        label: Text(_characterNames[id] ?? 'Character #$id'),
                        onPressed: () => openCatalogRecordDetail(
                          context: context,
                          auth: widget.auth,
                          kindApiValue: CatalogKind.characters.apiValue,
                          itemId: id,
                        ),
                      ),
                  ],
                ),
              ],
              if (record.description.trim().isNotEmpty) ...[
                const SizedBox(height: 24),
                Text('Description', style: textTheme.titleSmall),
                const SizedBox(height: 8),
                SimpleCardRichText(
                  content: record.description,
                  onWikiLinkTap: (kind, name) => openCatalogWikiLink(
                    context: context,
                    auth: widget.auth,
                    kindApiValue: kind,
                    name: name,
                  ),
                ),
              ],
              const SizedBox(height: 28),
              Text('Sub-organisations', style: textTheme.titleMedium),
              OrganisationTreeView(
                organisations: _all,
                rootParentId: _item.id,
                emptyLabel: 'No sub-organisations.',
                onTap: _openOrganisation,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
