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
import '../data/session_model.dart';
import 'session_form_sheet.dart';

class SessionDetailPage extends StatefulWidget {
  const SessionDetailPage({
    super.key,
    required this.auth,
    required this.item,
    this.campaigns = const [],
  });

  final AuthController auth;
  final CatalogItem item;
  final List<CatalogItem> campaigns;

  @override
  State<SessionDetailPage> createState() => _SessionDetailPageState();
}

class _SessionDetailPageState extends State<SessionDetailPage> {
  final _api = CatalogApi();
  late CatalogItem _item = widget.item;
  late List<CatalogItem> _campaigns = widget.campaigns;

  Future<String?> _token() => widget.auth.requireAccessToken();

  SessionRecord get _record => SessionRecord.fromCatalogPayload(
        name: _item.name,
        payload: _item.payload,
      );

  @override
  void initState() {
    super.initState();
    if (_campaigns.isEmpty) {
      _loadCampaigns();
    }
  }

  Future<void> _loadCampaigns() async {
    try {
      final token = await _token();
      if (token == null) return;
      final campaigns = await _api.list(token, CatalogKind.campaigns);
      if (!mounted) return;
      setState(() => _campaigns = campaigns);
    } catch (_) {}
  }

  CatalogItem? get _campaign {
    final campaignId = _record.campaignId;
    for (final c in _campaigns) {
      if (c.id == campaignId) return c;
    }
    return null;
  }

  Future<void> _edit() async {
    try {
      final token = await _token();
      if (token == null || !mounted) return;
      if (_campaigns.isEmpty) await _loadCampaigns();
      if (!mounted) return;
      final updatedRecord = await showSessionFormSheet(
        context,
        initial: _record,
        campaigns: _campaigns,
        searchLinks: (q) => searchCatalogLinkTargets(_api, token, q),
        loadAutoLinkTargets: () =>
            loadConditionDamageAutoLinkTargets(_api, token),
      );
      if (updatedRecord == null || !mounted) return;
      final updated = await _api.update(
        accessToken: token,
        kind: CatalogKind.sessions,
        itemId: _item.id,
        name: updatedRecord.name,
        payload: updatedRecord.toJson(),
      );
      if (!mounted) return;
      setState(() => _item = updated);
    } on AuthApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not update session')),
      );
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete session?'),
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
        kind: CatalogKind.sessions,
        itemId: _item.id,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on AuthApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not delete session')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final record = _record;
    final campaign = _campaign;
    final local = record.parsedDateTime?.toLocal();
    final dateLabel = local == null
        ? (record.dateTime.isEmpty ? 'No date set' : record.dateTime)
        : local.toString();

    return Scaffold(
      appBar: AppBar(
        title: Text(_item.name.trim().isEmpty ? 'Session' : _item.name),
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
                    sessionsPageIcon,
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
              Text(_item.name, style: textTheme.headlineSmall),
              const SizedBox(height: 4),
              if (campaign == null)
                Text(
                  'Campaign unknown',
                  style: textTheme.titleMedium?.copyWith(
                    color: scheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                )
              else
                InkWell(
                  onTap: () => openCatalogRecordDetail(
                    context: context,
                    auth: widget.auth,
                    kindApiValue: CatalogKind.campaigns.apiValue,
                    itemId: campaign.id,
                  ),
                  child: Text(
                    campaign.name,
                    style: textTheme.titleMedium?.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              Text(
                dateLabel,
                style: textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              if (record.description.trim().isNotEmpty) ...[
                const SizedBox(height: 20),
                Text('Notes', style: textTheme.titleSmall),
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
            ],
          ),
        ],
      ),
    );
  }
}
