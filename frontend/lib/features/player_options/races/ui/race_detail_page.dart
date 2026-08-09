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
import '../../player_options_icons.dart';
import '../data/race_model.dart';
import 'race_form_sheet.dart';
import 'race_overview_box.dart';

class RaceDetailPage extends StatefulWidget {
  const RaceDetailPage({
    super.key,
    required this.auth,
    required this.item,
  });

  final AuthController auth;
  final CatalogItem item;

  @override
  State<RaceDetailPage> createState() => _RaceDetailPageState();
}

class _RaceDetailPageState extends State<RaceDetailPage> {
  final _api = CatalogApi();
  late CatalogItem _item = widget.item;

  Future<String?> _token() => widget.auth.requireAccessToken();

  RaceRecord get _race => RaceRecord.fromCatalogPayload(
        name: _item.name,
        payload: _item.payload,
      );

  Future<void> _edit() async {
    try {
      final token = await _token();
      if (token == null || !mounted) return;
      final updatedRace = await showRaceFormSheet(
        context,
        initial: _race,
        searchLinks: (q) => searchCatalogLinkTargets(_api, token, q),
        loadAutoLinkTargets: () =>
            loadConditionDamageAutoLinkTargets(_api, token),
      );
      if (updatedRace == null || !mounted) return;
      final updated = await _api.update(
        accessToken: token,
        kind: CatalogKind.races,
        itemId: _item.id,
        name: updatedRace.name,
        payload: updatedRace.toJson(),
      );
      if (!mounted) return;
      setState(() => _item = updated);
    } on AuthApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not update race')),
      );
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete race?'),
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
        kind: CatalogKind.races,
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
        const SnackBar(content: Text('Could not delete race')),
      );
    }
  }

  Widget _articleTitle(RaceRecord record) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(_item.name, style: textTheme.headlineSmall),
        if (record.aliases.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            record.aliases.join(', '),
            style: textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }

  Widget _description(RaceRecord record, {Widget? floatEnd}) {
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
      floatEndWidth: RaceOverviewBox.preferredWidth,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final race = _race;

    return Scaffold(
      appBar: AppBar(
        title: Text(_item.name.trim().isEmpty ? 'Race' : _item.name),
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
                    racesPageIcon,
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
              final overview = RaceOverviewBox(
                auth: widget.auth,
                record: race,
              );
              return ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  WikiArticleLayout(
                    readableLineLength: widget.auth.readableLineLength,
                    title: _articleTitle(race),
                    overview: overview,
                    overviewWidth: RaceOverviewBox.preferredWidth,
                    bodyBuilder: (floatOverview) => _description(
                      race,
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
