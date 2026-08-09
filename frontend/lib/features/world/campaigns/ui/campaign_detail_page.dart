import 'package:flutter/material.dart';

import '../../../../core/offline/offline_marker.dart';
import '../../../../core/ui/record_list_card.dart';
import '../../../../core/ui/wiki_article_layout.dart';
import '../../../auth/data/auth_api.dart';
import '../../../auth/state/auth_controller.dart';
import '../../../catalog/data/catalog_api.dart';
import '../../../catalog/data/catalog_auto_link.dart';
import '../../../catalog/data/catalog_kind.dart';
import '../../../catalog/data/catalog_models.dart';
import '../../../catalog/ui/catalog_rich_text.dart';
import '../../../catalog/ui/open_catalog_detail.dart';
import '../../characters/data/character_model.dart';
import '../../ui/catalog_overview_box.dart';
import '../../world_icons.dart';
import '../data/campaign_model.dart';
import '../data/session_model.dart';
import 'campaign_form_sheet.dart';
import 'session_form_sheet.dart';

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
  List<CatalogItem> _sessions = const [];

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
        _api.list(token, CatalogKind.sessions),
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
      final sessions = [
        for (final s in results[2])
          if (SessionRecord.fromCatalogPayload(
                name: s.name,
                payload: s.payload,
              ).campaignId ==
              _item.id)
            s,
      ];
      setState(() {
        _characterNames = preferred.isEmpty ? all : {...all, ...preferred};
        _ruleNames = {for (final r in results[1]) r.id: r.name};
        _sessions = SessionRecord.sortByDateTime(
          items: sessions,
          dateTimeOf: (item) => SessionRecord.fromCatalogPayload(
            name: item.name,
            payload: item.payload,
          ).dateTime,
        );
      });
      await _migrateLegacySessionsIfNeeded(token);
    } catch (_) {}
  }

  Future<void> _migrateLegacySessionsIfNeeded(String token) async {
    final record = _record;
    if (record.legacySessions.isEmpty) return;

    final existingNames = {
      for (final s in _sessions) s.name.toLowerCase(),
    };
    final created = <CatalogItem>[];
    final sorted = [...record.legacySessions]..sort((a, b) {
        final da = a.parsedDateTime;
        final db = b.parsedDateTime;
        if (da == null && db == null) return 0;
        if (da == null) return 1;
        if (db == null) return -1;
        return da.compareTo(db);
      });

    for (var i = 0; i < sorted.length; i++) {
      final legacy = sorted[i];
      var name = legacy.title.trim();
      if (name.isEmpty) {
        name = '${record.name} s${i + 1}';
      }
      var unique = name;
      var suffix = 2;
      while (existingNames.contains(unique.toLowerCase())) {
        unique = '$name ($suffix)';
        suffix++;
      }
      existingNames.add(unique.toLowerCase());
      final item = await _api.create(
        accessToken: token,
        kind: CatalogKind.sessions,
        name: unique,
        payload: SessionRecord(
          name: unique,
          campaignId: _item.id,
          dateTime: legacy.dateTime,
        ).toJson(),
      );
      created.add(item);
    }

    final cleaned = await _api.update(
      accessToken: token,
      kind: CatalogKind.campaigns,
      itemId: _item.id,
      name: record.name,
      payload: record.copyWith(legacySessions: const []).toJson(),
    );
    if (!mounted) return;
    setState(() {
      _item = cleaned;
      _sessions = SessionRecord.sortByDateTime(
        items: [..._sessions, ...created],
        dateTimeOf: (item) => SessionRecord.fromCatalogPayload(
          name: item.name,
          payload: item.payload,
        ).dateTime,
      );
    });
  }

  Future<void> _addSession() async {
    try {
      final token = await _token();
      if (token == null || !mounted) return;
      final record = await showSessionFormSheet(
        context,
        campaigns: [_item],
        preferredCampaignId: _item.id,
        searchLinks: (q) => searchCatalogLinkTargets(_api, token, q),
        loadAutoLinkTargets: () =>
            loadConditionDamageAutoLinkTargets(_api, token),
      );
      if (record == null || !mounted) return;
      final created = await _api.create(
        accessToken: token,
        kind: CatalogKind.sessions,
        name: record.name,
        payload: record.copyWith(campaignId: _item.id).toJson(),
      );
      if (!mounted) return;
      setState(() {
        _sessions = SessionRecord.sortByDateTime(
          items: [..._sessions, created],
          dateTimeOf: (item) => SessionRecord.fromCatalogPayload(
            name: item.name,
            payload: item.payload,
          ).dateTime,
        );
      });
    } on AuthApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not create session')),
      );
    }
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

    return Scaffold(
      appBar: AppBar(
        title: Text(_item.name.trim().isEmpty ? 'Campaign' : _item.name),
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
                  child: Icon(storyPageIcon, size: 440, color: scheme.onSurface),
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
                icon: storyPageIcon,
                overviewSections: record.overviewSections,
              );
              return ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  WikiArticleLayout(
                    readableLineLength: widget.auth.readableLineLength,
                    title: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
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
                      ],
                    ),
                    overview: overview,
                    overviewWidth: CatalogOverviewBox.preferredWidth,
                    bodyBuilder: (floatOverview) {
                      if (record.description.trim().isNotEmpty) {
                        return CatalogRichText(
                          auth: widget.auth,
                          content: record.description,
                          floatEnd: floatOverview,
                          floatEndWidth: CatalogOverviewBox.preferredWidth,
                        );
                      }
                      if (floatOverview != null) {
                        return Align(
                          alignment: Alignment.topRight,
                          child: floatOverview,
                        );
                      }
                      return const SizedBox.shrink();
                    },
                    trailing: [
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
                                label: Text(
                                  _characterNames[id] ?? 'Character #$id',
                                ),
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
                      const SizedBox(height: 28),
                      Row(
                        children: [
                          Expanded(
                            child:
                                Text('Sessions', style: textTheme.titleMedium),
                          ),
                          if (widget.auth.canMutateCatalog)
                            TextButton.icon(
                              onPressed: _addSession,
                              icon: const Icon(Icons.add, size: 18),
                              label: const Text('Add'),
                            ),
                        ],
                      ),
                      if (_sessions.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            'No sessions linked to this campaign yet.',
                            style: textTheme.bodyMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        )
                      else
                        for (var i = 0; i < _sessions.length; i++)
                          Builder(
                            builder: (context) {
                              final sessionItem = _sessions[i];
                              final session = SessionRecord.fromCatalogPayload(
                                name: sessionItem.name,
                                payload: sessionItem.payload,
                              );
                              final local = session.parsedDateTime?.toLocal();
                              final subtitle = local?.toString() ??
                                  (session.dateTime.isEmpty
                                      ? null
                                      : session.dateTime);
                              final notes = session.descriptionPreview;
                              return Padding(
                                padding: const EdgeInsets.only(top: 10),
                                child: RecordListCard(
                                  leading: Container(
                                    width: 42,
                                    height: 42,
                                    decoration: BoxDecoration(
                                      color: scheme.primaryContainer.withValues(
                                        alpha: 0.88,
                                      ),
                                      borderRadius: BorderRadius.circular(13),
                                    ),
                                    child: Center(
                                      child: Text(
                                        's${i + 1}',
                                        style: textTheme.labelLarge?.copyWith(
                                          color: scheme.onPrimaryContainer,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                  ),
                                  title: sessionItem.name,
                                  subtitle: subtitle ?? '',
                                  trailing: Icon(
                                    Icons.chevron_right,
                                    color: scheme.onSurfaceVariant,
                                  ),
                                  onTap: () async {
                                    final deleted =
                                        await openCatalogRecordDetail(
                                      context: context,
                                      auth: widget.auth,
                                      kindApiValue:
                                          CatalogKind.sessions.apiValue,
                                      itemId: sessionItem.id,
                                    );
                                    if (deleted == true || mounted) {
                                      await _loadLookups();
                                    }
                                  },
                                  children: [
                                    if (notes.isNotEmpty) ...[
                                      const SizedBox(height: 10),
                                      Text(
                                        notes,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: textTheme.bodyMedium?.copyWith(
                                          color: scheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              );
                            },
                          ),
                    ],
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
