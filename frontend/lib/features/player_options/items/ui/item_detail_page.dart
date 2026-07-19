import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../core/ui/markdown_form_field.dart';
import '../../../../core/ui/mtg_card_rules_text_fit.dart';
import '../../../auth/data/auth_api.dart';
import '../../../auth/state/auth_controller.dart';
import '../../../catalog/data/catalog_api.dart';
import '../../../catalog/data/catalog_kind.dart';
import '../../../catalog/data/catalog_models.dart';
import '../../../dm_tools/resources/data/resource_models.dart';
import '../../../dm_tools/resources/data/resources_api.dart';
import '../../../export/card_export_pdf.dart';
import '../../../export/card_png_export_present.dart';
import '../../player_options_icons.dart';
import '../data/item_model.dart';
import 'item_form_sheet.dart';
import 'item_sheet.dart';

class ItemDetailPage extends StatefulWidget {
  const ItemDetailPage({
    super.key,
    required this.auth,
    required this.item,
    required this.entry,
    this.sourceFileName,
  });

  final AuthController auth;
  final CatalogItem item;
  final Item entry;
  final String? sourceFileName;

  @override
  State<ItemDetailPage> createState() => _ItemDetailPageState();
}

class _ItemDetailPageState extends State<ItemDetailPage> {
  final _api = CatalogApi();
  final _resourcesApi = ResourcesApi();

  late CatalogItem _item = widget.item;
  late Item _entry = widget.entry;
  late String? _sourceFileName = widget.sourceFileName;
  bool _exportingPng = false;

  Future<String?> _token() => widget.auth.requireAccessToken();

  bool _isDesktopPlatform() {
    final platform = defaultTargetPlatform;
    return platform == TargetPlatform.windows ||
        platform == TargetPlatform.macOS ||
        platform == TargetPlatform.linux;
  }

  Item? _itemFromCatalog(CatalogItem item) {
    final payload = item.payload;
    if (payload == null) return null;
    try {
      return Item.fromJson(payload);
    } catch (_) {
      return null;
    }
  }

  Future<({List<ResourceFile> files})> _loadFormLookups(String token) async {
    var files = const <ResourceFile>[];
    try {
      files = await _resourcesApi.listFiles(token);
    } on AuthApiException {
      // Non-DM users cannot list resources.
    } catch (_) {}
    return (files: files);
  }

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
      if (token == null) return;
      final lookups = await _loadFormLookups(token);
      if (!mounted) return;
      final updatedEntry = await showItemFormSheet(
        context,
        initial: _entry,
        resourceFiles: lookups.files,
        searchLinks: (query) => _searchLinks(token, query),
        loadAutoLinkTargets: () => _loadAutoLinkTargets(token),
      );
      if (updatedEntry == null || !mounted) return;
      final updated = await _api.update(
        accessToken: token,
        kind: CatalogKind.items,
        itemId: _item.id,
        name: updatedEntry.name,
        payload: updatedEntry.toJson(),
      );
      final parsed = _itemFromCatalog(updated) ?? updatedEntry;

      String? sourceName = _sourceFileName;
      if (parsed.sourceFileId != null) {
        for (final f in lookups.files) {
          if (f.id == parsed.sourceFileId) {
            sourceName = f.name;
            break;
          }
        }
      } else {
        sourceName = null;
      }

      if (!mounted) return;
      setState(() {
        _item = updated;
        _entry = parsed.copyWith(name: updated.name);
        _sourceFileName = sourceName;
      });
    } on AuthApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not update item')),
      );
    }
  }

  Future<void> _exportCardPng() async {
    if (_exportingPng) return;
    setState(() => _exportingPng = true);
    try {
      final bytes = await rasterizeItemCard(
        context: context,
        item: _entry,
        theme: Theme.of(context),
      );
      if (!mounted) return;
      await presentCardPngExport(
        bytes,
        '${cardExportSafeBaseName(_entry.name)}.png',
      );
    } catch (e, st) {
      debugPrint('Card PNG export failed: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save image: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _exportingPng = false);
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete item?'),
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
        kind: CatalogKind.items,
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
        const SnackBar(content: Text('Could not delete item')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final desktopScale = _isDesktopPlatform() ? 1.25 : 1.0;
    final topSpacing = _isDesktopPlatform() ? 48.0 : 0.0;
    final hasSource =
        _entry.sourceFileId != null || (_sourceFileName?.isNotEmpty ?? false);

    return Scaffold(
      appBar: AppBar(
        title: Text(_entry.name.trim().isEmpty ? 'Item' : _entry.name),
        actions: [
          IconButton(
            tooltip: 'Edit',
            icon: const Icon(Icons.edit_outlined),
            onPressed: _edit,
          ),
          IconButton(
            tooltip: 'Save as PNG',
            icon: const Icon(Icons.image_outlined),
            onPressed: _exportingPng ? null : _exportCardPng,
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
                    itemsPageIcon,
                    size: 440,
                    color: scheme.onSurface,
                  ),
                ),
              ),
            ),
          ),
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: EdgeInsets.only(top: topSpacing),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _CardPagesWrap(
                      cards: buildItemSheets(
                        _entry,
                        cardScale: desktopScale,
                        maxFontSize: kMtgCardRulesMaxFontSize * desktopScale,
                      ),
                      scaleFactor: desktopScale,
                    ),
                    if (hasSource) ...[
                      const SizedBox(height: 12),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 760),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: scheme.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: scheme.outlineVariant),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Sources',
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '${_sourceFileName ?? 'Resource ${_entry.sourceFileId}'}'
                                  '${_entry.sourcePage != null ? ' · p. ${_entry.sourcePage}' : ''}',
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CardPagesWrap extends StatelessWidget {
  final List<Widget> cards;
  final double scaleFactor;

  const _CardPagesWrap({required this.cards, this.scaleFactor = 1.0});

  @override
  Widget build(BuildContext context) {
    if (cards.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, constraints) {
        final targetCardWidth = 360.0 * scaleFactor;
        final canFitTwo = constraints.maxWidth >= (targetCardWidth * 2) + 12;
        final cardWidth = canFitTwo
            ? targetCardWidth
            : constraints.maxWidth.clamp(0.0, targetCardWidth).toDouble();
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          alignment: WrapAlignment.center,
          children: [
            for (final card in cards)
              SizedBox(
                width: cardWidth,
                child: card,
              ),
          ],
        );
      },
    );
  }
}
