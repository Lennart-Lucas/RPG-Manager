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
import '../data/character_model.dart';
import 'character_form_sheet.dart';
import 'mtg_alignment_chips.dart';

class CharacterDetailPage extends StatefulWidget {
  const CharacterDetailPage({
    super.key,
    required this.auth,
    required this.item,
  });

  final AuthController auth;
  final CatalogItem item;

  @override
  State<CharacterDetailPage> createState() => _CharacterDetailPageState();
}

class _CharacterDetailPageState extends State<CharacterDetailPage> {
  final _api = CatalogApi();
  late CatalogItem _item = widget.item;
  String? _raceName;
  List<CatalogItem> _races = const [];

  Future<String?> _token() => widget.auth.requireAccessToken();

  CharacterRecord get _record => CharacterRecord.fromCatalogPayload(
        name: _item.name,
        payload: _item.payload,
      );

  @override
  void initState() {
    super.initState();
    _loadRace();
  }

  Future<void> _loadRace() async {
    try {
      final token = await _token();
      if (token == null) return;
      final races = await _api.list(token, CatalogKind.races);
      if (!mounted) return;
      final raceId = _record.raceId;
      String? name;
      if (raceId != null) {
        for (final r in races) {
          if (r.id == raceId) {
            name = r.name;
            break;
          }
        }
      }
      setState(() {
        _races = races;
        _raceName = name;
      });
    } catch (_) {}
  }

  Future<void> _edit() async {
    try {
      final token = await _token();
      if (token == null || !mounted) return;
      if (_races.isEmpty) {
        _races = await _api.list(token, CatalogKind.races);
      }
      if (!mounted) return;
      final updatedRecord = await showCharacterFormSheet(
        context,
        initial: _record,
        races: _races,
        searchLinks: (q) => searchCatalogLinkTargets(_api, token, q),
        loadAutoLinkTargets: () =>
            loadConditionDamageAutoLinkTargets(_api, token),
      );
      if (updatedRecord == null || !mounted) return;
      final updated = await _api.update(
        accessToken: token,
        kind: CatalogKind.characters,
        itemId: _item.id,
        name: updatedRecord.name,
        payload: updatedRecord.toJson(),
      );
      if (!mounted) return;
      setState(() => _item = updated);
      await _loadRace();
    } on AuthApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not update character')),
      );
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete character?'),
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
        kind: CatalogKind.characters,
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
        const SnackBar(content: Text('Could not delete character')),
      );
    }
  }

  Widget _articleTitle(CharacterRecord record) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(_item.name, style: textTheme.headlineSmall),
        const SizedBox(height: 4),
        Text(
          'Character',
          style: textTheme.titleMedium?.copyWith(
            color: scheme.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _overviewBox(CharacterRecord record) {
    return CatalogOverviewBox(
      auth: widget.auth,
      title: record.name,
      icon: charactersPageIcon,
      imageUrl: record.imageUrl,
      overviewSections: record.overviewSections,
      leading: [
        if (_raceName != null || record.playerName.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (_raceName != null)
                  ActionChip(
                    label: Text(_raceName!),
                    avatar: const Icon(Icons.diversity_3_outlined, size: 18),
                    onPressed: record.raceId == null
                        ? null
                        : () => openCatalogRecordDetail(
                              context: context,
                              auth: widget.auth,
                              kindApiValue: CatalogKind.races.apiValue,
                              itemId: record.raceId!,
                            ),
                  ),
                if (record.playerName.isNotEmpty)
                  Chip(
                    avatar: const Icon(Icons.person_outline, size: 18),
                    label: Text(record.playerName),
                  ),
              ],
            ),
          ),
        if (record.mtgAlignment.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Alignment',
                  style: Theme.of(context).textTheme.titleSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                MtgAlignmentChips(
                  colors: record.mtgAlignment,
                  wrapAlignment: WrapAlignment.center,
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _description(CharacterRecord record, {Widget? floatEnd}) {
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
    return CatalogRichText(
      auth: widget.auth,
      content: record.description,
      floatEnd: floatEnd,
      floatEndWidth: CatalogOverviewBox.preferredWidth,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final record = _record;

    return Scaffold(
      appBar: AppBar(
        title: Text(_item.name.trim().isEmpty ? 'Character' : _item.name),
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
                    charactersPageIcon,
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
              final overview = _overviewBox(record);
              return ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  WikiArticleLayout(
                    readableLineLength: widget.auth.readableLineLength,
                    title: _articleTitle(record),
                    overview: overview,
                    overviewWidth: CatalogOverviewBox.preferredWidth,
                    bodyBuilder: (floatOverview) => _description(
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
