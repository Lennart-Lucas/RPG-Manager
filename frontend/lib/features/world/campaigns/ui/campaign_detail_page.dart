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
import '../../characters/data/character_model.dart';
import '../../world_icons.dart';
import '../data/campaign_model.dart';
import 'campaign_form_sheet.dart';

class CampaignDetailPage extends StatefulWidget {
  const CampaignDetailPage({
    super.key,
    required this.auth,
    required this.item,
  });

  final AuthController auth;
  final CatalogItem item;

  @override
  State<CampaignDetailPage> createState() => _CampaignDetailPageState();
}

class _CampaignDetailPageState extends State<CampaignDetailPage> {
  final _api = CatalogApi();
  late CatalogItem _item = widget.item;
  Map<int, String> _characterNames = const {};
  Map<int, String> _ruleNames = const {};

  Future<String?> _token() => widget.auth.requireAccessToken();

  CampaignRecord get _record => CampaignRecord.fromCatalogPayload(
        name: _item.name,
        payload: _item.payload,
      );

  @override
  void initState() {
    super.initState();
    _loadLookups();
  }

  Future<void> _loadLookups() async {
    try {
      final token = await _token();
      if (token == null) return;
      final results = await Future.wait([
        _api.list(token, CatalogKind.characters),
        _api.list(token, CatalogKind.rules),
      ]);
      if (!mounted) return;
      final chars = results[0];
      final preferred = <int, String>{};
      final all = <int, String>{};
      for (final c in chars) {
        all[c.id] = c.name;
        final record = CharacterRecord.fromCatalogPayload(
          name: c.name,
          payload: c.payload,
        );
        if (record.playerName.trim().isNotEmpty) {
          preferred[c.id] = '${c.name} (${record.playerName})';
        }
      }
      setState(() {
        _characterNames = preferred.isEmpty ? all : {...all, ...preferred};
        _ruleNames = {for (final r in results[1]) r.id: r.name};
      });
    } catch (_) {}
  }

  Future<void> _edit() async {
    try {
      final token = await _token();
      if (token == null || !mounted) return;
      if (_characterNames.isEmpty || _ruleNames.isEmpty) await _loadLookups();
      if (!mounted) return;
      final updatedRecord = await showCampaignFormSheet(
        context,
        initial: _record,
        characterNames: _characterNames,
        ruleNames: _ruleNames,
        searchLinks: (q) => searchCatalogLinkTargets(_api, token, q),
        loadAutoLinkTargets: () =>
            loadConditionDamageAutoLinkTargets(_api, token),
      );
      if (updatedRecord == null || !mounted) return;
      final updated = await _api.update(
        accessToken: token,
        kind: CatalogKind.campaigns,
        itemId: _item.id,
        name: updatedRecord.name,
        payload: updatedRecord.toJson(),
      );
      if (!mounted) return;
      setState(() => _item = updated);
    } on AuthApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not update campaign')),
      );
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete campaign?'),
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
        kind: CatalogKind.campaigns,
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
        const SnackBar(content: Text('Could not delete campaign')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final record = _record;
    final sessions = CampaignRecord.sortSessions(record.sessions);

    return Scaffold(
      appBar: AppBar(
        title: Text(_item.name.trim().isEmpty ? 'Campaign' : _item.name),
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
                  child: Icon(storyPageIcon, size: 440, color: scheme.onSurface),
                ),
              ),
            ),
          ),
          ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(_item.name, style: textTheme.headlineSmall),
              const SizedBox(height: 4),
              Text(
                'Campaign',
                style: textTheme.titleMedium?.copyWith(
                  color: scheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (record.description.trim().isNotEmpty) ...[
                const SizedBox(height: 20),
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
              if (record.playerCharacterIds.isNotEmpty) ...[
                const SizedBox(height: 24),
                Text('Players', style: textTheme.titleSmall),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final id in record.playerCharacterIds)
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
              if (record.houseRuleIds.isNotEmpty) ...[
                const SizedBox(height: 24),
                Text('House rules', style: textTheme.titleSmall),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final id in record.houseRuleIds)
                      ActionChip(
                        label: Text(_ruleNames[id] ?? 'Rule #$id'),
                        onPressed: () => openCatalogRecordDetail(
                          context: context,
                          auth: widget.auth,
                          kindApiValue: CatalogKind.rules.apiValue,
                          itemId: id,
                        ),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 24),
              Text('Sessions', style: textTheme.titleSmall),
              const SizedBox(height: 8),
              if (sessions.isEmpty)
                Text(
                  'No sessions yet.',
                  style: textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                )
              else
                for (var i = 0; i < sessions.length; i++)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      child: Text('s${i + 1}'),
                    ),
                    title: Text(
                      record.sessionDisplayNameAt(i + 1, sessions[i]),
                    ),
                    subtitle: Text(
                      sessions[i].parsedDateTime?.toLocal().toString() ??
                          sessions[i].dateTime,
                    ),
                  ),
            ],
          ),
        ],
      ),
    );
  }
}
