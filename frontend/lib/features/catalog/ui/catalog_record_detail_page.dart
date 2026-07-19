import 'package:flutter/material.dart';

import '../../auth/data/auth_api.dart';
import '../../auth/state/auth_controller.dart';
import '../../mechanics/spell_tags/data/spell_tag_model.dart';
import '../../mechanics/spell_tags/ui/spell_tag_form_sheet.dart';
import '../../player_options/classes/data/class_model.dart';
import '../../player_options/classes/ui/class_form_sheet.dart';
import '../data/catalog_api.dart';
import '../data/catalog_kind.dart';
import '../data/catalog_kind_icons.dart';
import '../data/catalog_models.dart';
import 'name_record_form_sheet.dart';
import 'open_catalog_detail.dart';

/// Simple detail page for catalog kinds that do not have a rich card view.
class CatalogRecordDetailPage extends StatefulWidget {
  const CatalogRecordDetailPage({
    super.key,
    required this.auth,
    required this.item,
  });

  final AuthController auth;
  final CatalogItem item;

  @override
  State<CatalogRecordDetailPage> createState() =>
      _CatalogRecordDetailPageState();
}

class _CatalogRecordDetailPageState extends State<CatalogRecordDetailPage> {
  final _api = CatalogApi();

  late CatalogItem _item = widget.item;

  Future<String?> _token() => widget.auth.requireAccessToken();

  Future<void> _edit() async {
    try {
      final token = await _token();
      if (token == null || !mounted) return;

      switch (_item.kind) {
        case CatalogKind.classes:
          final record = await showClassFormSheet(
            context,
            initial: ClassRecord.fromCatalogPayload(
              name: _item.name,
              payload: _item.payload,
            ),
          );
          if (record == null || !mounted) return;
          final updated = await _api.update(
            accessToken: token,
            kind: CatalogKind.classes,
            itemId: _item.id,
            name: record.name,
            payload: record.toJson(),
          );
          setState(() => _item = updated);
        case CatalogKind.spellTags:
          final tag = await showSpellTagFormSheet(
            context,
            initial: SpellTag.fromCatalogPayload(
              name: _item.name,
              payload: _item.payload,
            ),
            searchLinks: (query) async {
              final results = await _api.search(token, query: query);
              return results;
            },
            loadAutoLinkTargets: () async => const [],
          );
          if (tag == null || !mounted) return;
          final updated = await _api.update(
            accessToken: token,
            kind: CatalogKind.spellTags,
            itemId: _item.id,
            name: tag.name,
            payload: tag.toJson(),
          );
          setState(() => _item = updated);
        default:
          final name = await showNameRecordFormSheet(
            context,
            singularLabel: _item.kind.singularLabel,
            initialName: _item.name,
          );
          if (name == null || !mounted) return;
          final updated = await _api.update(
            accessToken: token,
            kind: _item.kind,
            itemId: _item.id,
            name: name,
          );
          setState(() => _item = updated);
      }
    } on AuthApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not update ${_item.kind.singularLabel}'),
        ),
      );
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete ${_item.kind.singularLabel}?'),
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
        kind: _item.kind,
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
        SnackBar(
          content: Text('Could not delete ${_item.kind.singularLabel}'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final subtitle = catalogRecordSubtitle(_item);

    return Scaffold(
      appBar: AppBar(
        title: Text(_item.name.trim().isEmpty ? _item.kind.displayLabel : _item.name),
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
                    _item.kind.pageIcon,
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
                      _item.kind.pageIcon,
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
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _item.kind.displayLabel,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: scheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 24),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
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
