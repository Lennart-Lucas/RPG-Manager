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
import '../../player_options_icons.dart';
import '../data/class_model.dart';
import '../data/subclass_model.dart';
import 'subclass_form_sheet.dart';

class SubclassDetailPage extends StatefulWidget {
  const SubclassDetailPage({
    super.key,
    required this.auth,
    required this.item,
    this.parentClasses = const [],
  });

  final AuthController auth;
  final CatalogItem item;
  final List<CatalogItem> parentClasses;

  @override
  State<SubclassDetailPage> createState() => _SubclassDetailPageState();
}

class _SubclassDetailPageState extends State<SubclassDetailPage> {
  final _api = CatalogApi();
  late CatalogItem _item = widget.item;
  late List<CatalogItem> _parentClasses = widget.parentClasses;

  Future<String?> _token() => widget.auth.requireAccessToken();

  SubclassRecord get _record => SubclassRecord.fromCatalogPayload(
        name: _item.name,
        payload: _item.payload,
      );

  @override
  void initState() {
    super.initState();
    if (_parentClasses.isEmpty) {
      _loadParents();
    }
  }

  Future<void> _loadParents() async {
    try {
      final token = await _token();
      if (token == null) return;
      final classes = await _api.list(token, CatalogKind.classes);
      if (!mounted) return;
      setState(() => _parentClasses = classes);
    } catch (_) {}
  }

  CatalogItem? get _parentClass {
    final parentId = _record.parentClassId;
    for (final c in _parentClasses) {
      if (c.id == parentId) return c;
    }
    return null;
  }

  int get _chosenAtLevel {
    final parent = _parentClass;
    if (parent == null) return 3;
    return ClassRecord.fromCatalogPayload(
      name: parent.name,
      payload: parent.payload,
    ).subclassChosenAtLevel;
  }

  Future<void> _edit() async {
    try {
      final token = await _token();
      if (token == null || !mounted) return;
      if (_parentClasses.isEmpty) await _loadParents();
      if (!mounted) return;
      final updatedRecord = await showSubclassFormSheet(
        context,
        initial: _record,
        parentClasses: _parentClasses,
        searchLinks: (q) => searchCatalogLinkTargets(_api, token, q),
        loadAutoLinkTargets: () =>
            loadConditionDamageAutoLinkTargets(_api, token),
      );
      if (updatedRecord == null || !mounted) return;
      final updated = await _api.update(
        accessToken: token,
        kind: CatalogKind.subclasses,
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
        const SnackBar(content: Text('Could not update subclass')),
      );
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete subclass?'),
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
        kind: CatalogKind.subclasses,
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
        const SnackBar(content: Text('Could not delete subclass')),
      );
    }
  }

  Widget _featureSection(
    BuildContext context,
    Map<int, List<ClassFeature>> featuresByLevel,
  ) {
    final textTheme = Theme.of(context).textTheme;
    final levels = featuresByLevel.keys.toList()..sort();
    if (levels.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(
          'No features yet',
          style: textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final level in levels) ...[
          const SizedBox(height: 12),
          Text('Level $level', style: textTheme.titleSmall),
          for (final feature in featuresByLevel[level] ?? const []) ...[
            const SizedBox(height: 8),
            Text(
              feature.name,
              style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            Text(
              feature.type.label,
              style: textTheme.labelMedium?.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            if (feature.description.trim().isNotEmpty) ...[
              const SizedBox(height: 4),
              SimpleCardRichText(
                content: feature.description,
                onWikiLinkTap: (kind, name) => openCatalogWikiLink(
                  context: context,
                  auth: widget.auth,
                  kindApiValue: kind,
                  name: name,
                ),
              ),
            ],
          ],
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final record = _record;
    final parent = _parentClass;
    final chosenAt = _chosenAtLevel;

    return Scaffold(
      appBar: AppBar(
        title: Text(_item.name),
        actions: [
          const OfflineAppBarMarker(),
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
                    subclassesPageIcon,
                    size: 440,
                    color: scheme.onSurface,
                  ),
                ),
              ),
            ),
          ),
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                parent == null
                    ? 'Parent class unknown'
                    : '${parent.name} · Chosen at level $chosenAt',
                style: textTheme.titleMedium?.copyWith(
                  color: scheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (parent != null) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => openCatalogWikiLink(
                      context: context,
                      auth: widget.auth,
                      kindApiValue: CatalogKind.classes.apiValue,
                      name: parent.name,
                    ),
                    icon: const Icon(Icons.shield_outlined, size: 18),
                    label: Text('Open ${parent.name}'),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              Text('Features', style: textTheme.titleMedium),
              _featureSection(context, record.featuresByLevel),
            ],
          ),
        ],
      ),
    );
  }
}
