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
import '../../world_icons.dart';
import '../data/character_model.dart';
import 'character_form_sheet.dart';
import 'character_overview_box.dart';

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

  Widget _overviewBox(CharacterRecord record) {
    return CharacterOverviewBox(
      auth: widget.auth,
      record: record,
      raceName: _raceName,
      onRaceTap: record.raceId == null
          ? null
          : () => openCatalogRecordDetail(
                context: context,
                auth: widget.auth,
                kindApiValue: CatalogKind.races.apiValue,
                itemId: record.raceId!,
              ),
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
      floatEndWidth: CharacterOverviewBox.preferredWidth,
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
                    title: WikiArticleTitle(
                      name: _item.name,
                      aliases: record.aliases,
                    ),
                    overview: overview,
                    overviewWidth: CharacterOverviewBox.preferredWidth,
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
