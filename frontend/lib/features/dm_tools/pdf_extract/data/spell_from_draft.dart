import 'dart:convert';

import '../../../catalog/data/catalog_models.dart';
import '../../../player_options/spells/data/spell_ai_template.dart';
import '../../../player_options/spells/data/spell_model.dart';
import 'extract_models.dart';

/// Build a [Spell] from an extract draft for review / commit.
Spell spellFromExtractDraft({
  required ExtractDraft draft,
  required List<CatalogItem> casterClasses,
  required List<CatalogItem> spellTags,
  int? sourceFileId,
}) {
  // After Edit, payload is Spell.toJson() (classIds/tagIds). Prefer that shape
  // so Approve does not drop classes by re-parsing the AI extract schema.
  final fromEdited = _trySpellFromEditedPayload(
    draft.payload,
    sourceFileId: sourceFileId,
  );
  if (fromEdited != null) return fromEdited;

  final normalized = _normalizePayload(
    draft.payload,
    casterClasses: casterClasses,
    spellTags: spellTags,
  );
  final jsonText = const JsonEncoder().convert(normalized);

  try {
    final template = parseSpellAiTemplate(
      clipboardText: jsonText,
      casterClasses: casterClasses,
      spellTags: spellTags,
      allowUnknownNames: true,
    );
    final higher = template.higherLevels.trim().isEmpty
        ? null
        : SpellScaling(description: template.higherLevels);

    var description = template.description;
    if (description.trim().isEmpty &&
        draft.notes != null &&
        draft.notes!.trim().isNotEmpty) {
      description = draft.notes!.trim();
    }

    return Spell(
      id: Spell.slugify(
        template.name.isEmpty ? draft.displayName : template.name,
      ),
      name: template.name.isEmpty ? draft.displayName : template.name,
      level: template.level,
      school: template.school,
      castingTime: CastingTime(
        amount: template.castAmount,
        unit: template.castUnit,
        reactionTrigger: template.reactionTrigger,
      ),
      range: switch (template.rangeKey) {
        'self' => const SpellRange.self(),
        'touch' => const SpellRange.touch(),
        final key when key.startsWith('ranged:') => SpellRange(
            type: RangeType.ranged,
            distanceFeet: int.tryParse(key.split(':').last) ?? 30,
          ),
        _ => const SpellRange.self(),
      },
      components: SpellComponents(
        verbal: template.verbal,
        somatic: template.somatic,
        material: template.material,
        materialDescription: template.materialDescription,
        materialCostGp: template.materialCostGp,
        materialConsumed: template.materialConsumed,
      ),
      duration: SpellDuration(
        type: template.durationType,
        concentration: template.concentration,
        special: template.durationSpecial,
      ),
      classIds: template.classIds,
      tagIds: template.tagIds,
      description: description,
      higherLevels: higher,
      sourceFileId: sourceFileId,
      sourcePage: template.sourcePage ?? draft.source.page,
    );
  } on SpellAiTemplateException {
    final name = draft.displayName;
    return Spell(
      id: Spell.slugify(name),
      name: name,
      level: (draft.payload['level'] as num?)?.toInt().clamp(0, 9) ?? 0,
      school: SpellSchool.evocation,
      castingTime: const CastingTime.action(),
      range: const SpellRange.self(),
      components: const SpellComponents(
        verbal: true,
        somatic: true,
        material: false,
      ),
      duration: const SpellDuration.instantaneous(),
      classIds: _idList(draft.payload['classIds']),
      tagIds: _idList(draft.payload['tagIds']),
      description: (draft.payload['description'] as String?) ??
          draft.notes ??
          draft.sourceText,
      sourceFileId: sourceFileId,
      sourcePage: draft.source.page ??
          (draft.payload['sourcePage'] as num?)?.toInt(),
    );
  }
}

/// Payload written by Edit ([Spell.toJson]) — distinguished by `classIds`.
Spell? _trySpellFromEditedPayload(
  Map<String, dynamic> payload, {
  int? sourceFileId,
}) {
  if (!payload.containsKey('classIds')) return null;
  if (payload['castingTime'] is! Map || payload['range'] is! Map) return null;

  try {
    final map = Map<String, dynamic>.from(payload);
    final name = (map['name'] as String?)?.trim();
    map['id'] = (map['id'] as String?)?.trim().isNotEmpty == true
        ? map['id']
        : Spell.slugify(name == null || name.isEmpty ? 'spell' : name);

    final higher = map['higherLevels'];
    if (higher is String) {
      final trimmed = higher.trim();
      map['higherLevels'] =
          trimmed.isEmpty ? null : <String, dynamic>{'description': trimmed};
    }

    final spell = Spell.fromJson(map);
    return spell.copyWith(
      sourceFileId: sourceFileId ?? spell.sourceFileId,
    );
  } catch (_) {
    return null;
  }
}

List<int> _idList(Object? raw) {
  if (raw is! List) return const [];
  final ids = <int>[];
  for (final item in raw) {
    if (item is int) {
      ids.add(item);
    } else if (item is num) {
      ids.add(item.toInt());
    }
  }
  return ids;
}

Map<String, dynamic> _normalizePayload(
  Map<String, dynamic> raw, {
  required List<CatalogItem> casterClasses,
  required List<CatalogItem> spellTags,
}) {
  final map = Map<String, dynamic>.from(raw);

  map['castingTime'] ??= {
    'amount': 1,
    'unit': 'action',
    'reactionTrigger': null,
  };
  if (map['castingTime'] is Map) {
    final casting = Map<String, dynamic>.from(map['castingTime'] as Map);
    casting['amount'] ??= 1;
    casting['unit'] ??= 'action';
    map['castingTime'] = casting;
  }

  map['range'] ??= {'type': 'self', 'distanceFeet': null};
  if (map['range'] is Map) {
    final range = Map<String, dynamic>.from(map['range'] as Map);
    range['type'] ??= 'self';
    final type = (range['type'] as String?)?.toLowerCase();
    if (type == 'ranged') {
      final feet = range['distanceFeet'];
      const allowed = {30, 60, 90, 120, 150, 300, 500};
      final asInt = feet is int
          ? feet
          : feet is num
              ? feet.toInt()
              : int.tryParse('$feet');
      if (asInt == null || !allowed.contains(asInt)) {
        range['distanceFeet'] = 30;
      }
    }
    map['range'] = range;
  }

  map['components'] ??= {
    'verbal': true,
    'somatic': true,
    'material': false,
    'materialDescription': null,
    'materialCostGp': null,
    'materialConsumed': false,
  };

  map['duration'] ??= {
    'type': 'instantaneous',
    'concentration': false,
    'special': null,
  };

  map['school'] ??= 'evocation';
  map['level'] ??= 0;
  map['description'] ??= '';

  // AI template expects name lists; convert catalog ids when present.
  map['classes'] = _classesOrTagsForTemplate(
    names: map['classes'],
    ids: map['classIds'],
    catalog: casterClasses,
  );
  map['tags'] = _classesOrTagsForTemplate(
    names: map['tags'],
    ids: map['tagIds'],
    catalog: spellTags,
  );

  final higher = map['higherLevels'];
  if (higher is Map) {
    map['higherLevels'] = higher['description'] as String? ?? '';
  } else if (higher == null) {
    map['higherLevels'] = '';
  }

  return map;
}

List<String> _classesOrTagsForTemplate({
  required Object? names,
  required Object? ids,
  required List<CatalogItem> catalog,
}) {
  final fromNames = <String>[];
  if (names is List) {
    for (final raw in names) {
      final text = '$raw'.trim();
      if (text.isNotEmpty) fromNames.add(text);
    }
  }
  if (fromNames.isNotEmpty) return fromNames;

  if (ids is! List || ids.isEmpty) return const [];
  final byId = {for (final item in catalog) item.id: item.name};
  return [
    for (final raw in ids)
      if (raw is int && byId[raw] != null)
        byId[raw]!
      else if (raw is num && byId[raw.toInt()] != null)
        byId[raw.toInt()]!,
  ];
}
