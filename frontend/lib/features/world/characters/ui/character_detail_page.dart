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

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
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
          ListView(
            padding: const EdgeInsets.all(24),
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
              const SizedBox(height: 16),
              if (_raceName != null || record.playerName.isNotEmpty)
                Wrap(
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
              if (record.mtgAlignment.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text('Alignment', style: textTheme.titleSmall),
                const SizedBox(height: 8),
                MtgAlignmentChips(colors: record.mtgAlignment),
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
            ],
          ),
        ],
      ),
    );
  }
}
