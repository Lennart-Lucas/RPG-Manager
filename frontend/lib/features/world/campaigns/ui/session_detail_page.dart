import 'package:flutter/material.dart';

import '../../../../core/offline/offline_marker.dart';
import '../../../../core/ui/wiki_article_layout.dart';
import '../../../auth/data/auth_api.dart';
import '../../../auth/state/auth_controller.dart';
import '../../../catalog/data/catalog_api.dart';
import '../../../catalog/data/catalog_auto_link.dart';
import '../../../catalog/data/catalog_kind.dart';
import '../../../catalog/data/catalog_models.dart';
import '../../../catalog/ui/catalog_rich_text.dart';
import '../../../catalog/ui/open_catalog_detail.dart';
import '../../ui/catalog_overview_box.dart';
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

  Widget _notes(SessionRecord record, {Widget? floatEnd}) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    if (record.description.trim().isEmpty) {
      if (floatEnd != null) {
        return Align(alignment: Alignment.topRight, child: floatEnd);
      }
      return Text(
        'No description yet.',
        style: textTheme.bodyLarge?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Notes', style: textTheme.titleSmall),
        const SizedBox(height: 8),
        CatalogRichText(
          auth: widget.auth,
          content: record.description,
          floatEnd: floatEnd,
          floatEndWidth: CatalogOverviewBox.preferredWidth,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
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
                    sessionsPageIcon,
                    size: 440,
                    color: scheme.onSurface,
                  ),
                ),
              ),
            ),
          ),
          AnimatedBuilder(
            animation: widget.auth,
            builder: (context, _) {
              final overview = CatalogOverviewBox(
                auth: widget.auth,
                title: record.name,
                icon: sessionsPageIcon,
                overviewSections: record.overviewSections,
                leading: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                    child: Text(
                      dateLabel,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                  ),
                ],
              );
              return ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  WikiArticleLayout(
                    readableLineLength: widget.auth.readableLineLength,
                    title: WikiArticleTitle(
                      name: _item.name,
                      below: [
                        if (campaign == null)
                          Text(
                            'Campaign unknown',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
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
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    color: scheme.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ),
                        Text(
                          dateLabel,
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                    overview: overview,
                    overviewWidth: CatalogOverviewBox.preferredWidth,
                    bodyBuilder: (floatOverview) => _notes(
                      record,
                      floatEnd: floatOverview,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
