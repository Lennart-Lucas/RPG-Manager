import 'package:flutter/material.dart';

import '../../../../core/offline/offline_marker.dart';
import '../../../auth/data/auth_api.dart';
import '../../../auth/state/auth_controller.dart';
import '../../../catalog/data/catalog_api.dart';
import '../../../catalog/data/catalog_auto_link.dart';
import '../../../catalog/data/catalog_kind.dart';
import '../../../catalog/data/catalog_models.dart';
import '../../../catalog/ui/catalog_rich_text.dart';
import '../../../catalog/ui/open_catalog_detail.dart';
import '../../world_icons.dart';
import '../data/organisation_model.dart';
import 'organisation_form_sheet.dart';
import 'organisation_overview_box.dart';
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
  static const _wideBreakpoint = 900.0;

  final _api = CatalogApi();
  late CatalogItem _item = widget.item;
  Map<int, String> _characterNames = const {};
  Map<int, String> _locationNames = const {};
  Map<int, CatalogItem> _locationsById = const {};
  List<CatalogItem> _all = const [];

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
        _api.list(token, CatalogKind.locations),
      ]);
      if (!mounted) return;
      final chars = results[0];
      final orgs = results[1];
      final locations = results[2];
      setState(() {
        _characterNames = {for (final c in chars) c.id: c.name};
        _locationNames = {for (final l in locations) l.id: l.name};
        _locationsById = {for (final l in locations) l.id: l};
        _all = orgs;
      });
    } catch (_) {}
  }

  Future<void> _edit() async {
    try {
      final token = await _token();
      if (token == null || !mounted) return;
      if (_characterNames.isEmpty ||
          _all.isEmpty ||
          _locationNames.isEmpty) {
        await _loadRelated();
      }
      if (!mounted) return;
      final updatedRecord = await showOrganisationFormSheet(
        context,
        initial: _record,
        characterNames: _characterNames,
        locationNames: _locationNames,
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

  Future<void> _openLocation(CatalogItem item) async {
    await openCatalogRecordDetail(
      context: context,
      auth: widget.auth,
      kindApiValue: CatalogKind.locations.apiValue,
      itemId: item.id,
    );
    if (mounted) await _loadRelated();
  }

  Widget _articleTitle(OrganisationRecord record) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(_item.name, style: textTheme.headlineSmall),
        if (record.aliases.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            record.aliases.join(', '),
            style: textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }

  Widget _overviewBox() {
    final record = _record;
    final orgsById = {for (final o in _all) o.id: o};
    return OrganisationOverviewBox(
      auth: widget.auth,
      record: record,
      seat: record.seatId == null ? null : _locationsById[record.seatId!],
      parentBody:
          record.parentId == null ? null : orgsById[record.parentId!],
      onSeatTap: _openLocation,
      onParentTap: _openOrganisation,
    );
  }

  Widget _members(OrganisationRecord record) {
    if (record.memberIds.isEmpty) return const SizedBox.shrink();
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
    );
  }

  Widget _description(OrganisationRecord record) {
    if (record.description.trim().isEmpty) return const SizedBox.shrink();
    return CatalogRichText(
      auth: widget.auth,
      content: record.description,
    );
  }

  Widget _subOrganisations() {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Sub-organisations', style: textTheme.titleMedium),
        OrganisationTreeView(
          organisations: _all,
          rootParentId: _item.id,
          emptyLabel: 'No sub-organisations.',
          onTap: _openOrganisation,
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
        title: Text(_item.name.trim().isEmpty ? 'Organisation' : _item.name),
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
                  child: Icon(
                    organisationsPageIcon,
                    size: 440,
                    color: scheme.onSurface,
                  ),
                ),
              ),
            ),
          ),
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= _wideBreakpoint;
              final hasMembers = record.memberIds.isNotEmpty;
              final hasDescription = record.description.trim().isNotEmpty;
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
                              if (hasMembers) ...[
                                const SizedBox(height: 20),
                                _members(record),
                              ],
                              if (hasDescription) ...[
                                const SizedBox(height: 24),
                                _description(record),
                              ],
                              const SizedBox(height: 28),
                              _subOrganisations(),
                            ],
                          ),
                        ),
                        const SizedBox(width: 24),
                        SizedBox(
                          width: OrganisationOverviewBox.preferredWidth,
                          child: _overviewBox(),
                        ),
                      ],
                    )
                  else ...[
                    _articleTitle(record),
                    const SizedBox(height: 16),
                    _overviewBox(),
                    if (hasMembers) ...[
                      const SizedBox(height: 20),
                      _members(record),
                    ],
                    if (hasDescription) ...[
                      const SizedBox(height: 24),
                      _description(record),
                    ],
                    const SizedBox(height: 28),
                    _subOrganisations(),
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
