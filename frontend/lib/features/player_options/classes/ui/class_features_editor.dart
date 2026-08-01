import 'package:flutter/material.dart';

import '../../../../core/ui/markdown_form_field.dart';
import '../../../dm_tools/resources/ui/resource_form_helpers.dart';
import '../data/class_model.dart';

/// Shared editor for class / subclass features grouped by level.
class ClassFeaturesEditor extends StatelessWidget {
  const ClassFeaturesEditor({
    required this.title,
    required this.features,
    required this.onChanged,
    this.searchLinks,
    this.loadAutoLinkTargets,
    super.key,
  });

  final String title;
  final List<ClassFeature> features;
  final ValueChanged<List<ClassFeature>> onChanged;
  final CatalogLinkSearch? searchLinks;
  final CatalogAutoLinkLoader? loadAutoLinkTargets;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        for (var i = 0; i < features.length; i++)
          Card(
            margin: const EdgeInsets.only(top: 8),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          initialValue: features[i].name,
                          decoration: ResourceFormStyles.inputDecoration(
                            context,
                            label: 'Feature name',
                          ),
                          onChanged: (value) {
                            final next = [...features];
                            next[i] = next[i].copyWith(name: value);
                            onChanged(next);
                          },
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          onChanged([...features]..removeAt(i));
                        },
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          initialValue: features[i].level.clamp(1, 20),
                          decoration: ResourceFormStyles.inputDecoration(
                            context,
                            label: 'Level',
                          ),
                          items: [
                            for (var level = 1; level <= 20; level++)
                              DropdownMenuItem(
                                value: level,
                                child: Text('$level'),
                              ),
                          ],
                          onChanged: (value) {
                            if (value == null) return;
                            final next = [...features];
                            next[i] = next[i].copyWith(level: value);
                            onChanged(next);
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<ClassFeatureType>(
                          initialValue: features[i].type,
                          decoration: ResourceFormStyles.inputDecoration(
                            context,
                            label: 'Type',
                          ),
                          items: [
                            for (final t in ClassFeatureType.values)
                              DropdownMenuItem(
                                value: t,
                                child: Text(t.label),
                              ),
                          ],
                          onChanged: (value) {
                            if (value == null) return;
                            final next = [...features];
                            next[i] = next[i].copyWith(type: value);
                            onChanged(next);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  MarkdownFormField(
                    key: ValueKey('feat-desc-$i-${features[i].id}'),
                    initialValue: features[i].description,
                    label: 'Description',
                    minLines: 2,
                    maxLines: 6,
                    searchLinks: searchLinks,
                    loadAutoLinkTargets: loadAutoLinkTargets,
                    onChanged: (value) {
                      final next = [...features];
                      next[i] = next[i].copyWith(description: value);
                      onChanged(next);
                    },
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    initialValue: features[i].mechanics == null
                        ? ''
                        : features[i]
                            .mechanics!
                            .entries
                            .map((e) => '${e.key}=${e.value}')
                            .join(', '),
                    decoration: ResourceFormStyles.inputDecoration(
                      context,
                      label: 'Mechanics (key=value, …)',
                      hintText: 'usesPerRest=2, resetOn=long',
                    ),
                    onChanged: (value) {
                      final next = [...features];
                      final parsed = parseClassFeatureMechanics(value);
                      next[i] = next[i].copyWith(
                        mechanics: parsed,
                        clearMechanics: parsed == null,
                      );
                      onChanged(next);
                    },
                  ),
                ],
              ),
            ),
          ),
        TextButton.icon(
          onPressed: () {
            onChanged([
              ...features,
              ClassFeature(
                id: 'feature-${features.length + 1}',
                name: '',
                level: 1,
              ),
            ]);
          },
          icon: const Icon(Icons.add),
          label: const Text('Add feature'),
        ),
      ],
    );
  }
}

Map<String, dynamic>? parseClassFeatureMechanics(String raw) {
  final text = raw.trim();
  if (text.isEmpty) return null;
  final map = <String, dynamic>{};
  for (final part in text.split(',')) {
    final piece = part.trim();
    if (piece.isEmpty) continue;
    final eq = piece.indexOf('=');
    if (eq <= 0) {
      map[piece] = true;
      continue;
    }
    final key = piece.substring(0, eq).trim();
    final value = piece.substring(eq + 1).trim();
    if (key.isEmpty) continue;
    final asInt = int.tryParse(value);
    if (asInt != null) {
      map[key] = asInt;
    } else if (value == 'true' || value == 'false') {
      map[key] = value == 'true';
    } else {
      map[key] = value;
    }
  }
  return map.isEmpty ? null : map;
}

Map<int, List<ClassFeature>> groupClassFeaturesByLevel(
  List<ClassFeature> features,
) {
  final map = <int, List<ClassFeature>>{};
  for (final f in features) {
    if (f.name.trim().isEmpty && f.description.trim().isEmpty) continue;
    final level = f.level.clamp(1, 20);
    final cleaned = f.copyWith(
      id: f.id.trim().isEmpty ? slugifyClassPart(f.name) : f.id,
      name: f.name.trim(),
      level: level,
      description: f.description.trim(),
    );
    map.putIfAbsent(level, () => []).add(cleaned);
  }
  return map;
}

List<ClassFeature> flattenClassFeaturesByLevel(
  Map<int, List<ClassFeature>> featuresByLevel,
) {
  return [
    for (final entry in featuresByLevel.entries)
      ...entry.value.map((f) => f.copyWith(level: entry.key)),
  ];
}
