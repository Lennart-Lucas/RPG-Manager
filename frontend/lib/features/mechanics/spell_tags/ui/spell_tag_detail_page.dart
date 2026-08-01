import 'package:flutter/material.dart';

import '../../../../core/offline/offline_marker.dart';
import '../../../../core/ui/markdown_form_field.dart';
import '../../../../core/ui/simple_card_rich_text.dart';
import '../../../auth/data/auth_api.dart';
import '../../../auth/state/auth_controller.dart';
import '../../../catalog/data/catalog_api.dart';
import '../../../catalog/data/catalog_kind.dart';
import '../../../catalog/data/catalog_models.dart';
import '../../../catalog/ui/open_catalog_detail.dart';
import '../../mechanics_icons.dart';
import '../data/spell_tag_model.dart';
import 'spell_tag_form_sheet.dart';

class SpellTagDetailPage extends StatefulWidget {
  const SpellTagDetailPage({
    super.key,
    required this.auth,
    required this.item,
  });

  final AuthController auth;
  final CatalogItem item;

  @override
  State<SpellTagDetailPage> createState() => _SpellTagDetailPageState();
}

class _SpellTagDetailPageState extends State<SpellTagDetailPage> {
  final _api = CatalogApi();

  late CatalogItem _item = widget.item;

  Future<String?> _token() => widget.auth.requireAccessToken();

  SpellTag get _tag => SpellTag.fromCatalogPayload(
        name: _item.name,
        payload: _item.payload,
      );

  Future<List<CatalogLinkTarget>> _searchLinks(
    String token,
    String query,
  ) async {
    var nameQuery = query;
    String? kindPrefix;
    final slash = query.lastIndexOf('/');
    if (slash >= 0) {
      kindPrefix = query.substring(0, slash).trim().toLowerCase();
      nameQuery = query.substring(slash + 1);
    }
    try {
      final results = await _api.search(token, query: nameQuery);
      if (kindPrefix == null || kindPrefix.isEmpty) return results;
      return results
          .where((item) => item.kind.toLowerCase().startsWith(kindPrefix!))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<List<CatalogLinkTarget>> _loadAutoLinkTargets(String token) async {
    try {
      final results = await Future.wait([
        _api.list(token, CatalogKind.conditions),
        _api.list(token, CatalogKind.damageTypes),
      ]);
      return [
        for (final item in results[0])
          CatalogLinkTarget(
            id: item.id,
            kind: item.kind.apiValue,
            name: item.name,
          ),
        for (final item in results[1])
          CatalogLinkTarget(
            id: item.id,
            kind: item.kind.apiValue,
            name: item.name,
          ),
      ];
    } catch (_) {
      return const [];
    }
  }

  Future<void> _edit() async {
    try {
      final token = await _token();
      if (token == null || !mounted) return;
      final updatedTag = await showSpellTagFormSheet(
        context,
        initial: _tag,
        searchLinks: (query) => _searchLinks(token, query),
        loadAutoLinkTargets: () => _loadAutoLinkTargets(token),
      );
      if (updatedTag == null || !mounted) return;
      final updated = await _api.update(
        accessToken: token,
        kind: CatalogKind.spellTags,
        itemId: _item.id,
        name: updatedTag.name,
        payload: updatedTag.toJson(),
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
        const SnackBar(content: Text('Could not update spell tag')),
      );
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete spell tag?'),
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
        kind: CatalogKind.spellTags,
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
        const SnackBar(content: Text('Could not delete spell tag')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final tag = _tag;

    return Scaffold(
      appBar: AppBar(
        title: Text(_item.name.trim().isEmpty ? 'Spell tag' : _item.name),
        actions: [
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
          const OfflineAppBarMarker(),
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
                    spellTagsPageIcon,
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
              Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer.withValues(alpha: 0.88),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      spellTagsPageIcon,
                      color: scheme.onPrimaryContainer,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _item.name,
                          style: textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Spell tag',
                          style: textTheme.titleMedium?.copyWith(
                            color: scheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (tag.description.trim().isNotEmpty) ...[
                const SizedBox(height: 24),
                SimpleCardRichText(
                  content: tag.description,
                  onWikiLinkTap: (kind, name) => openCatalogWikiLink(
                    context: context,
                    auth: widget.auth,
                    kindApiValue: kind,
                    name: name,
                  ),
                ),
              ] else ...[
                const SizedBox(height: 24),
                Text(
                  'No description yet.',
                  style: textTheme.bodyLarge?.copyWith(
                    color: scheme.onSurfaceVariant,
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
