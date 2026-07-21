import 'package:flutter/material.dart';

import '../../auth/data/auth_api.dart';
import '../../auth/state/auth_controller.dart';
import '../../../core/ui/simple_card_rich_text.dart';
import '../../mechanics/item_properties/data/item_property_model.dart';
import '../../mechanics/item_properties/ui/item_property_form_sheet.dart';
import '../../mechanics/rules/data/rule_model.dart';
import '../../mechanics/rules/ui/rule_form_sheet.dart';
import '../../mechanics/spell_tags/data/spell_tag_model.dart';
import '../../mechanics/spell_tags/ui/spell_tag_form_sheet.dart';
import '../../player_options/classes/data/class_model.dart';
import '../../player_options/classes/ui/class_form_sheet.dart';
import '../../player_options/feats/data/feat_model.dart';
import '../../player_options/feats/ui/feat_form_sheet.dart';
import '../../player_options/skills/data/default_skills.dart';
import '../../player_options/skills/data/skill_model.dart';
import '../../player_options/skills/ui/skill_form_sheet.dart';
import '../../settings/generators/data/generator_model.dart';
import '../../settings/generators/ui/generator_form_sheet.dart';
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
  List<CatalogItem> _rules = const [];
  bool _loadingRules = false;

  @override
  void initState() {
    super.initState();
    if (_item.kind == CatalogKind.rules) {
      _loadRules();
    }
  }

  Future<String?> _token() => widget.auth.requireAccessToken();

  Future<void> _loadRules() async {
    setState(() => _loadingRules = true);
    try {
      final token = await _token();
      if (token == null) return;
      final items = await _api.list(token, CatalogKind.rules);
      if (!mounted) return;
      setState(() {
        _rules = items;
        _loadingRules = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingRules = false);
    }
  }

  String? get _parentRuleName {
    if (_item.kind != CatalogKind.rules) return null;
    final rule = RuleRecord.fromCatalogPayload(
      name: _item.name,
      payload: _item.payload,
    );
    final parentId = rule.parentRuleId;
    if (parentId == null) return null;
    for (final item in _rules) {
      if (item.id == parentId) return item.name;
    }
    return 'Rule #$parentId';
  }

  Future<void> _edit() async {
    if (_item.kind == CatalogKind.skills && isDefaultSkillName(_item.name)) {
      return;
    }
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
        case CatalogKind.skills:
          final skill = await showSkillFormSheet(
            context,
            initial: SkillRecord.fromCatalogPayload(
              name: _item.name,
              payload: _item.payload,
            ),
          );
          if (skill == null || !mounted) return;
          final updated = await _api.update(
            accessToken: token,
            kind: CatalogKind.skills,
            itemId: _item.id,
            name: skill.name,
            payload: skill.toJson(),
          );
          setState(() => _item = updated);
        case CatalogKind.generators:
          final record = await showGeneratorFormSheet(
            context,
            initial: GeneratorRecord.fromCatalogPayload(
              name: _item.name,
              payload: _item.payload,
            ),
          );
          if (record == null || !mounted) return;
          final updated = await _api.update(
            accessToken: token,
            kind: CatalogKind.generators,
            itemId: _item.id,
            name: record.name,
            payload: record.toJson(),
          );
          setState(() => _item = updated);
        case CatalogKind.rules:
          if (_rules.isEmpty && !_loadingRules) {
            await _loadRules();
          }
          if (!mounted) return;
          final rule = await showRuleFormSheet(
            context,
            initial: RuleRecord.fromCatalogPayload(
              name: _item.name,
              payload: _item.payload,
            ),
            editingItemId: _item.id,
            siblingRules: _rules.isEmpty ? [_item] : _rules,
            searchLinks: (query) async => _api.search(token, query: query),
            loadAutoLinkTargets: () async => const [],
          );
          if (rule == null || !mounted) return;
          final updated = await _api.update(
            accessToken: token,
            kind: CatalogKind.rules,
            itemId: _item.id,
            name: rule.name,
            payload: rule.toJson(),
          );
          setState(() => _item = updated);
          await _loadRules();
        case CatalogKind.feats:
          final feat = await showFeatFormSheet(
            context,
            initial: FeatRecord.fromCatalogPayload(
              name: _item.name,
              payload: _item.payload,
            ),
            searchLinks: (query) async => _api.search(token, query: query),
            loadAutoLinkTargets: () async => const [],
          );
          if (feat == null || !mounted) return;
          final updated = await _api.update(
            accessToken: token,
            kind: CatalogKind.feats,
            itemId: _item.id,
            name: feat.name,
            payload: feat.toJson(),
          );
          setState(() => _item = updated);
        case CatalogKind.itemProperties:
          final property = await showItemPropertyFormSheet(
            context,
            initial: ItemPropertyRecord.fromCatalogPayload(
              name: _item.name,
              payload: _item.payload,
            ),
            searchLinks: (query) async => _api.search(token, query: query),
            loadAutoLinkTargets: () async => const [],
          );
          if (property == null || !mounted) return;
          final updated = await _api.update(
            accessToken: token,
            kind: CatalogKind.itemProperties,
            itemId: _item.id,
            name: property.name,
            payload: property.toJson(),
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
    if (_item.kind == CatalogKind.skills && isDefaultSkillName(_item.name)) {
      return;
    }
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
    final isLockedDefault = _item.kind == CatalogKind.skills &&
        isDefaultSkillName(_item.name);

    return Scaffold(
      appBar: AppBar(
        title: Text(_item.name.trim().isEmpty ? _item.kind.displayLabel : _item.name),
        actions: [
          if (!isLockedDefault) ...[
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
              if (_item.kind == CatalogKind.rules) ...[
                Builder(
                  builder: (context) {
                    final rule = RuleRecord.fromCatalogPayload(
                      name: _item.name,
                      payload: _item.payload,
                    );
                    final parentName = _parentRuleName;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (parentName != null) ...[
                          const SizedBox(height: 24),
                          Text(
                            'Parent',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          const SizedBox(height: 6),
                          Text(parentName),
                        ],
                        if (rule.body.trim().isNotEmpty) ...[
                          const SizedBox(height: 24),
                          Text(
                            'Body',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          const SizedBox(height: 8),
                          SimpleCardRichText(content: rule.body),
                        ],
                      ],
                    );
                  },
                ),
              ],
              if (_item.kind == CatalogKind.feats) ...[
                Builder(
                  builder: (context) {
                    final feat = FeatRecord.fromCatalogPayload(
                      name: _item.name,
                      payload: _item.payload,
                    );
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (feat.requirement.trim().isNotEmpty) ...[
                          const SizedBox(height: 24),
                          Text(
                            'Requirement',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          const SizedBox(height: 8),
                          SimpleCardRichText(content: feat.requirement),
                        ],
                        if (feat.description.trim().isNotEmpty) ...[
                          const SizedBox(height: 24),
                          Text(
                            'Description',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          const SizedBox(height: 8),
                          SimpleCardRichText(content: feat.description),
                        ],
                      ],
                    );
                  },
                ),
              ],
              if (_item.kind == CatalogKind.itemProperties) ...[
                Builder(
                  builder: (context) {
                    final property = ItemPropertyRecord.fromCatalogPayload(
                      name: _item.name,
                      payload: _item.payload,
                    );
                    if (property.description.trim().isEmpty) {
                      return const SizedBox.shrink();
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 24),
                        Text(
                          'Description',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 8),
                        SimpleCardRichText(content: property.description),
                      ],
                    );
                  },
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
