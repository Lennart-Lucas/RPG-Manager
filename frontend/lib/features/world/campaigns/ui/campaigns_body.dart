import 'package:flutter/material.dart';

import '../../../../core/ui/record_list_card.dart';
import '../../../auth/data/auth_api.dart';
import '../../../auth/state/auth_controller.dart';
import '../../../catalog/data/catalog_api.dart';
import '../../../catalog/data/catalog_auto_link.dart';
import '../../../catalog/data/catalog_kind.dart';
import '../../../catalog/data/catalog_models.dart';
import '../../../catalog/ui/open_catalog_detail.dart';
import '../../characters/data/character_model.dart';
import '../../world_icons.dart';
import '../data/campaign_model.dart';
import '../data/session_model.dart';
import 'campaign_form_sheet.dart';

class CampaignsBody extends StatefulWidget {
  const CampaignsBody({super.key, required this.auth});

  final AuthController auth;

  @override
  State<CampaignsBody> createState() => _CampaignsBodyState();
}

class _CampaignsBodyState extends State<CampaignsBody> {
  final _api = CatalogApi();
  bool _loading = true;
  String? _error;
  List<CatalogItem> _items = const [];
  Map<int, String> _characterNames = const {};
  Map<int, String> _ruleNames = const {};
  Map<int, int> _sessionCounts = const {};

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<String?> _token() => widget.auth.requireAccessToken();

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final token = await _token();
      if (token == null) throw AuthApiException('Not authenticated');
      final results = await Future.wait([
        _api.list(token, CatalogKind.campaigns),
        _api.list(token, CatalogKind.characters),
        _api.list(token, CatalogKind.rules),
        _api.list(token, CatalogKind.sessions),
      ]);
      if (!mounted) return;
      final chars = results[1];
      final names = <int, String>{};
      for (final c in chars) {
        final record = CharacterRecord.fromCatalogPayload(
          name: c.name,
          payload: c.payload,
        );
        names[c.id] = record.playerName.trim().isEmpty
            ? c.name
            : '${c.name} (${record.playerName})';
      }
      final sessionCounts = <int, int>{};
      for (final s in results[3]) {
        final campaignId = SessionRecord.fromCatalogPayload(
          name: s.name,
          payload: s.payload,
        ).campaignId;
        if (campaignId <= 0) continue;
        sessionCounts[campaignId] = (sessionCounts[campaignId] ?? 0) + 1;
      }
      for (final campaign in results[0]) {
        final legacy = CampaignRecord.fromCatalogPayload(
          name: campaign.name,
          payload: campaign.payload,
        ).legacySessions.length;
        if (legacy > 0) {
          sessionCounts[campaign.id] =
              (sessionCounts[campaign.id] ?? 0) + legacy;
        }
      }
      setState(() {
        _items = results[0];
        _characterNames = names;
        _ruleNames = {for (final r in results[2]) r.id: r.name};
        _sessionCounts = sessionCounts;
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
        _error = 'Could not load campaigns';
        _loading = false;
      });
    }
  }

  Future<void> _create() async {
    try {
      final token = await _token();
      if (token == null || !mounted) return;
      final record = await showCampaignFormSheet(
        context,
        characterNames: _characterNames,
        ruleNames: _ruleNames,
        searchLinks: (q) => searchCatalogLinkTargets(_api, token, q),
        loadAutoLinkTargets: () =>
            loadConditionDamageAutoLinkTargets(_api, token),
      );
      if (record == null || !mounted) return;
      await _api.create(
        accessToken: token,
        kind: CatalogKind.campaigns,
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
        const SnackBar(content: Text('Could not create campaign')),
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
        title: const Text('Delete campaign?'),
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
        kind: CatalogKind.campaigns,
        itemId: item.id,
      );
      await _reload();
    } on AuthApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not delete campaign')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Stack(
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: Center(
              child: Opacity(
                opacity: 0.08,
                child: Icon(storyPageIcon, size: 440, color: scheme.onSurface),
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
                        child: Text(
                          widget.auth.canMutateCatalog
                              ? 'No campaigns yet\nTap + to add one.'
                              : 'No campaigns yet.',
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
                final record = CampaignRecord.fromCatalogPayload(
                  name: item.name,
                  payload: item.payload,
                );
                final sessionCount = _sessionCounts[item.id] ?? 0;
                return RecordListCard(
                  leading: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer.withValues(alpha: 0.88),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(
                      storyPageIcon,
                      size: 22,
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                  title: item.name,
                  subtitle:
                      '${record.playerCharacterIds.length} players · $sessionCount session${sessionCount == 1 ? '' : 's'}',
                  trailing: widget.auth.canMutateCatalog
                      ? IconButton(
                          tooltip: 'Delete',
                          onPressed: () => _delete(item),
                          icon: Icon(
                            Icons.delete_outline,
                            color: scheme.onSurfaceVariant,
                          ),
                        )
                      : null,
                  onTap: () => _open(item),
                  children: [
                    if (record.descriptionPreview.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        record.descriptionPreview,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
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
