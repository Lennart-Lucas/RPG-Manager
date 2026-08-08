import 'package:flutter/material.dart';

import '../../../../core/offline/offline_marker.dart';
import '../../../../core/ui/markdown_form_field.dart';
import '../../../../core/ui/simple_card_rich_text.dart';
import '../../../auth/data/auth_api.dart';
import '../../../auth/state/auth_controller.dart';
import '../../../catalog/data/catalog_api.dart';
import '../../../catalog/data/catalog_auto_link.dart';
import '../../../catalog/data/catalog_kind.dart';
import '../../../catalog/data/catalog_models.dart';
import '../../../catalog/ui/open_catalog_detail.dart';
import '../../mechanics_icons.dart';
import '../data/rule_model.dart';
import 'rule_form_sheet.dart';

class RuleDetailPage extends StatefulWidget {
  const RuleDetailPage({
    super.key,
    required this.auth,
    required this.item,
    this.siblingRules = const [],
  });

  final AuthController auth;
  final CatalogItem item;
  final List<CatalogItem> siblingRules;

  @override
  State<RuleDetailPage> createState() => _RuleDetailPageState();
}

class _RuleDetailPageState extends State<RuleDetailPage> {
  final _api = CatalogApi();

  late CatalogItem _item = widget.item;
  late List<CatalogItem> _siblingRules = widget.siblingRules;
  bool _loadingSiblings = false;

  Future<String?> _token() => widget.auth.requireAccessToken();

  RuleRecord get _rule => RuleRecord.fromCatalogPayload(
        name: _item.name,
        payload: _item.payload,
      );

  @override
  void initState() {
    super.initState();
    if (_siblingRules.isEmpty) {
      _loadSiblingRules();
    }
  }

  Future<void> _loadSiblingRules() async {
    setState(() => _loadingSiblings = true);
    try {
      final token = await _token();
      if (token == null) return;
      final items = await _api.list(token, CatalogKind.rules);
      if (!mounted) return;
      setState(() {
        _siblingRules = items;
        _loadingSiblings = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingSiblings = false);
    }
  }

  String? get _parentRuleName {
    final parentId = _rule.parentRuleId;
    if (parentId == null) return null;
    for (final item in _siblingRules) {
      if (item.id == parentId) return item.name;
    }
    return 'Rule #$parentId';
  }

  CatalogItem? get _parentRuleItem {
    final parentId = _rule.parentRuleId;
    if (parentId == null) return null;
    for (final item in _siblingRules) {
      if (item.id == parentId) return item;
    }
    return null;
  }

  List<CatalogItem> get _childRules {
    return _siblingRules
        .where((item) {
          if (item.id == _item.id) return false;
          final child = RuleRecord.fromCatalogPayload(
            name: item.name,
            payload: item.payload,
          );
          return child.parentRuleId == _item.id;
        })
        .toList()
      ..sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );
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

  Future<void> _edit() async {
    try {
      final token = await _token();
      if (token == null || !mounted) return;
      if (_siblingRules.isEmpty && !_loadingSiblings) {
        await _loadSiblingRules();
      }
      if (!mounted) return;
      final updatedRule = await showRuleFormSheet(
        context,
        initial: _rule,
        editingItemId: _item.id,
        siblingRules: _siblingRules.isEmpty ? [_item] : _siblingRules,
        searchLinks: (query) => _searchLinks(token, query),
        loadAutoLinkTargets: () =>
            loadConditionDamageAutoLinkTargets(_api, token),
      );
      if (updatedRule == null || !mounted) return;
      final updated = await _api.update(
        accessToken: token,
        kind: CatalogKind.rules,
        itemId: _item.id,
        name: updatedRule.name,
        payload: updatedRule.toJson(),
      );
      if (!mounted) return;
      setState(() => _item = updated);
      await _loadSiblingRules();
    } on AuthApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not update rule')),
      );
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete rule?'),
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
        kind: CatalogKind.rules,
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
        const SnackBar(content: Text('Could not delete rule')),
      );
    }
  }

  Future<void> _openRelatedRule(CatalogItem item) async {
    final deleted = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => RuleDetailPage(
          auth: widget.auth,
          item: item,
          siblingRules: _siblingRules,
        ),
      ),
    );
    if (!mounted) return;
    if (deleted == true || deleted == null) {
      await _loadSiblingRules();
      // Refresh current item in case siblings changed names.
      try {
        final token = await _token();
        if (token == null) return;
        final refreshed = await _api.get(token, CatalogKind.rules, _item.id);
        if (!mounted) return;
        setState(() => _item = refreshed);
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final rule = _rule;
    final parentName = _parentRuleName;
    final parentItem = _parentRuleItem;
    final children = _childRules;

    return Scaffold(
      appBar: AppBar(
        title: Text(_item.name.trim().isEmpty ? 'Rule' : _item.name),
        actions: [
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
                    rulesPageIcon,
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
                      rulesPageIcon,
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
                          'Rule',
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
              if (parentName != null) ...[
                const SizedBox(height: 24),
                Text('Parent', style: textTheme.titleSmall),
                const SizedBox(height: 6),
                if (parentItem != null)
                  InkWell(
                    onTap: () => _openRelatedRule(parentItem),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              parentName,
                              style: textTheme.bodyLarge?.copyWith(
                                color: scheme.primary,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.chevron_right,
                            color: scheme.onSurfaceVariant,
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Text(parentName, style: textTheme.bodyLarge),
              ],
              if (children.isNotEmpty) ...[
                const SizedBox(height: 24),
                Text('Child rules', style: textTheme.titleSmall),
                const SizedBox(height: 8),
                for (final child in children)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(rulesPageIcon, color: scheme.primary),
                    title: Text(child.name),
                    trailing: Icon(
                      Icons.chevron_right,
                      color: scheme.onSurfaceVariant,
                    ),
                    onTap: () => _openRelatedRule(child),
                  ),
              ],
              if (rule.body.trim().isNotEmpty) ...[
                const SizedBox(height: 24),
                Text('Body', style: textTheme.titleSmall),
                const SizedBox(height: 8),
                SimpleCardRichText(
                  content: rule.body,
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
                  'No body yet.',
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
