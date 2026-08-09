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
import '../../ui/catalog_overview_box.dart';
import '../../world_icons.dart';
import '../data/lore_model.dart';
import 'lore_form_sheet.dart';

class LoreDetailPage extends StatefulWidget {
  const LoreDetailPage({
    super.key,
    required this.auth,
    required this.item,
  });

  final AuthController auth;
  final CatalogItem item;

  @override
  State<LoreDetailPage> createState() => _LoreDetailPageState();
}

class _LoreDetailPageState extends State<LoreDetailPage> {
  final _api = CatalogApi();
  late CatalogItem _item = widget.item;

  Future<String?> _token() => widget.auth.requireAccessToken();

  LoreRecord get _record => LoreRecord.fromCatalogPayload(
        name: _item.name,
        payload: _item.payload,
      );

  Future<void> _edit() async {
    try {
      final token = await _token();
      if (token == null || !mounted) return;
      final updatedRecord = await showLoreFormSheet(
        context,
        initial: _record,
        searchLinks: (q) => searchCatalogLinkTargets(_api, token, q),
        loadAutoLinkTargets: () =>
            loadConditionDamageAutoLinkTargets(_api, token),
      );
      if (updatedRecord == null || !mounted) return;
      final updated = await _api.update(
        accessToken: token,
        kind: CatalogKind.lore,
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
        const SnackBar(content: Text('Could not update lore')),
      );
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete lore?'),
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
        kind: CatalogKind.lore,
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
        const SnackBar(content: Text('Could not delete lore')),
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
        title: Text(_item.name.trim().isEmpty ? 'Lore' : _item.name),
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
                    lorePageIcon,
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
                icon: lorePageIcon,
                overviewSections: record.overviewSections,
              );
              return ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  WikiArticleLayout(
                    readableLineLength: widget.auth.readableLineLength,
                    title: WikiArticleTitle(name: _item.name),
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
                      return Text(
                        'No description yet.',
                        style: textTheme.bodyLarge?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      );
                    },
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
