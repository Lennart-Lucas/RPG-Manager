import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../core/ui/markdown_form_field.dart';
import '../../../../core/ui/mtg_card_rules_text_fit.dart';
import '../../../auth/data/auth_api.dart';
import '../../../auth/state/auth_controller.dart';
import '../../../catalog/data/catalog_api.dart';
import '../../../catalog/data/catalog_kind.dart';
import '../../../catalog/data/catalog_models.dart';
import '../../../export/card_export_pdf.dart';
import '../../../export/card_png_export_present.dart';
import '../../player_options_icons.dart';
import '../data/feat_model.dart';
import 'feat_form_sheet.dart';
import 'feat_sheet.dart';

class FeatDetailPage extends StatefulWidget {
  const FeatDetailPage({
    super.key,
    required this.auth,
    required this.item,
    required this.entry,
  });

  final AuthController auth;
  final CatalogItem item;
  final FeatRecord entry;

  @override
  State<FeatDetailPage> createState() => _FeatDetailPageState();
}

class _FeatDetailPageState extends State<FeatDetailPage> {
  final _api = CatalogApi();

  late CatalogItem _item = widget.item;
  late FeatRecord _entry = widget.entry;
  bool _exportingPng = false;

  Future<String?> _token() => widget.auth.requireAccessToken();

  bool _isDesktopPlatform() {
    final platform = defaultTargetPlatform;
    return platform == TargetPlatform.windows ||
        platform == TargetPlatform.macOS ||
        platform == TargetPlatform.linux;
  }

  FeatRecord? _featFromCatalog(CatalogItem item) {
    try {
      return FeatRecord.fromCatalogPayload(
        name: item.name,
        payload: item.payload,
        id: FeatRecord.slugify(item.name),
      );
    } catch (_) {
      return null;
    }
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
      if (token == null || !mounted) return;
      final updatedEntry = await showFeatFormSheet(
        context,
        initial: _entry,
        searchLinks: (query) => _searchLinks(token, query),
        loadAutoLinkTargets: () => _loadAutoLinkTargets(token),
      );
      if (updatedEntry == null || !mounted) return;
      final updated = await _api.update(
        accessToken: token,
        kind: CatalogKind.feats,
        itemId: _item.id,
        name: updatedEntry.name,
        payload: updatedEntry.toJson(),
      );
      final parsed = _featFromCatalog(updated) ?? updatedEntry;

      if (!mounted) return;
      setState(() {
        _item = updated;
        _entry = parsed.copyWith(name: updated.name);
      });
    } on AuthApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not update feat')),
      );
    }
  }

  Future<void> _exportCardPng() async {
    if (_exportingPng) return;
    setState(() => _exportingPng = true);
    try {
      final bytes = await rasterizeFeatCard(
        context: context,
        feat: _entry,
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
        title: const Text('Delete feat?'),
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
        kind: CatalogKind.feats,
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
        const SnackBar(content: Text('Could not delete feat')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final desktopScale = _isDesktopPlatform() ? 1.25 : 1.0;
    final topSpacing = _isDesktopPlatform() ? 48.0 : 0.0;

    return Scaffold(
      appBar: AppBar(
        title: Text(_entry.name.trim().isEmpty ? 'Feat' : _entry.name),
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
                    featsPageIcon,
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
                child: _CardPagesWrap(
                  cards: buildFeatSheets(
                    _entry,
                    cardScale: desktopScale,
                    maxFontSize: kMtgCardRulesMaxFontSize * desktopScale,
                  ),
                  scaleFactor: desktopScale,
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
