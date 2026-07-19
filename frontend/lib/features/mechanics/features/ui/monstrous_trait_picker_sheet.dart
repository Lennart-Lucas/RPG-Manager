import 'package:flutter/material.dart';

import '../../../dm_tools/resources/ui/resource_form_helpers.dart';
import '../data/feature_model.dart';
import '../data/monstrous_traits_catalog.dart';

Future<MonsterFeature?> showMonstrousTraitPickerSheet(BuildContext context) {
  return showAdaptiveResourceForm<MonsterFeature>(
    context,
    title: 'Monstrous trait',
    child: const _MonstrousTraitPicker(),
  );
}

class _MonstrousTraitPicker extends StatefulWidget {
  const _MonstrousTraitPicker();

  @override
  State<_MonstrousTraitPicker> createState() => _MonstrousTraitPickerState();
}

class _MonstrousTraitPickerState extends State<_MonstrousTraitPicker> {
  MonstrousTraitsCatalog? _catalog;
  String? _loadError;
  String? _category;
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _loadCatalog();
    _searchController.addListener(() {
      setState(() => _query = _searchController.text);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCatalog() async {
    try {
      final catalog = await MonstrousTraitsCatalog.load();
      if (!mounted) return;
      setState(() {
        _catalog = catalog;
        _loadError = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadError = 'Could not load monstrous traits catalog');
    }
  }

  Future<void> _selectTrait(MonstrousTrait trait) async {
    final values = <String, String>{};
    if (trait.parameters.isNotEmpty) {
      final controllers = {
        for (final param in trait.parameters)
          param: TextEditingController(),
      };
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(trait.name),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final param in trait.parameters) ...[
                  TextFormField(
                    controller: controllers[param],
                    decoration: ResourceFormStyles.inputDecoration(
                      ctx,
                      label: param,
                    ),
                  ),
                  const SizedBox(height: ResourceFormStyles.fieldSpacing),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Use trait'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
      for (final param in trait.parameters) {
        values[param] = controllers[param]!.text.trim();
      }
      for (final c in controllers.values) {
        c.dispose();
      }
    }

    if (!mounted) return;
    Navigator.pop(
      context,
      MonsterFeature(
        name: trait.name,
        category: FeatureCategory.trait,
        activationTime: FeatureActivation.none,
        text: trait.filledDescription(values),
        textOverride: true,
        monstrousTraitId: trait.id,
        budgetSlot: FeatureBudgetSlot.ancestral,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loadError != null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_loadError!, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          FilledButton(onPressed: _loadCatalog, child: const Text('Retry')),
        ],
      );
    }
    if (_catalog == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final categories = _catalog!.categories;
    final traits = _catalog!.filter(category: _category, query: _query);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _searchController,
          decoration: ResourceFormStyles.inputDecoration(
            context,
            label: 'Search',
            hintText: 'Name, keyword, or description',
          ),
        ),
        const SizedBox(height: ResourceFormStyles.fieldSpacing),
        DropdownButtonFormField<String?>(
          initialValue: _category,
          decoration: ResourceFormStyles.inputDecoration(
            context,
            label: 'Category',
          ),
          items: [
            const DropdownMenuItem<String?>(
              value: null,
              child: Text('All categories'),
            ),
            for (final c in categories)
              DropdownMenuItem(value: c, child: Text(c)),
          ],
          onChanged: (v) => setState(() => _category = v),
        ),
        const SizedBox(height: ResourceFormStyles.sectionSpacing),
        if (traits.isEmpty)
          const Text('No traits match your filters.')
        else
          ...traits.map(
            (trait) => Material(
              color: Theme.of(context)
                  .colorScheme
                  .surfaceContainerHighest
                  .withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(8),
              child: ListTile(
                title: Text(trait.name),
                subtitle: Text(
                  trait.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: trait.parameters.isEmpty
                    ? null
                    : Chip(label: Text('${trait.parameters.length} params')),
                onTap: () => _selectTrait(trait),
              ),
            ),
          ),
      ],
    );
  }
}
