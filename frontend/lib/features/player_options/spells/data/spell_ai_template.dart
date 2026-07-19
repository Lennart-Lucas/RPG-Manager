import 'dart:convert';

import '../../../catalog/data/catalog_models.dart';
import 'spell_model.dart';

/// Clipboard marker before the JSON template block.
const spellAiTemplateMarker = 'In the following template:';

/// Allowed casting-time units for AI templates (matches spell form).
const spellAiCastingTimeUnits = <String>[
  'action',
  'bonus action',
  'reaction',
  'minute',
  'hour',
];

/// Allowed ranged distances in feet (matches spell form).
const spellAiRangedDistances = <int>[30, 60, 90, 120, 150, 300, 500];

/// Empty JSON map used when copying a blank AI fill template.
///
/// Includes `*Options` arrays so external AI knows allowed picklist values.
/// Paste ignores those option lists and only reads the fillable fields.
Map<String, dynamic> emptySpellAiTemplateJson({
  List<String> classOptions = const [],
  List<String> tagOptions = const [],
}) =>
    {
      'name': '',
      'level': 0,
      'levelOptions': [for (var level = 0; level <= 9; level++) level],
      'school': 'evocation',
      'schoolOptions': [
        for (final school in SpellSchool.values) school.name,
      ],
      'castingTime': {
        'amount': 1,
        'unit': 'action',
        'unitOptions': spellAiCastingTimeUnits,
        'reactionTrigger': null,
      },
      'range': {
        'type': 'self',
        'typeOptions': ['self', 'touch', 'ranged'],
        'distanceFeet': null,
        'distanceFeetOptions': spellAiRangedDistances,
      },
      'components': {
        'verbal': true,
        'somatic': true,
        'material': false,
        'materialDescription': null,
        'materialCostGp': null,
        'materialConsumed': false,
      },
      'duration': {
        'type': 'instantaneous',
        'typeOptions': [
          for (final type in DurationType.values) type.name,
        ],
        'concentration': false,
        'special': null,
      },
      'classes': <String>[],
      'classOptions': classOptions,
      'tags': <String>[],
      'tagOptions': tagOptions,
      'description': '',
      'higherLevels': '',
      'sourcePage': null,
    };

String buildSpellAiClipboardText({
  List<CatalogItem> casterClasses = const [],
  List<CatalogItem> spellTags = const [],
}) {
  final json = const JsonEncoder.withIndent('  ').convert(
    emptySpellAiTemplateJson(
      classOptions: [
        for (final item in casterClasses) item.name,
      ]..sort(),
      tagOptions: [
        for (final item in spellTags) item.name,
      ]..sort(),
    ),
  );
  return 'Copy the following spell:\n'
      '\n'
      '\n'
      '$spellAiTemplateMarker\n'
      '$json\n';
}

/// Parsed AI template ready to apply to the spell form.
class SpellAiTemplateData {
  const SpellAiTemplateData({
    required this.name,
    required this.level,
    required this.school,
    required this.castAmount,
    required this.castUnit,
    required this.reactionTrigger,
    required this.rangeKey,
    required this.verbal,
    required this.somatic,
    required this.material,
    required this.materialDescription,
    required this.materialCostGp,
    required this.materialConsumed,
    required this.durationType,
    required this.concentration,
    required this.durationSpecial,
    required this.classIds,
    required this.tagIds,
    required this.description,
    required this.higherLevels,
    required this.sourcePage,
  });

  final String name;
  final int level;
  final SpellSchool school;
  final int castAmount;
  final String castUnit;
  final String? reactionTrigger;
  final String rangeKey;
  final bool verbal;
  final bool somatic;
  final bool material;
  final String? materialDescription;
  final double? materialCostGp;
  final bool materialConsumed;
  final DurationType durationType;
  final bool concentration;
  final String? durationSpecial;
  final List<int> classIds;
  final List<int> tagIds;
  final String description;
  final String higherLevels;
  final int? sourcePage;
}

class SpellAiTemplateException implements Exception {
  SpellAiTemplateException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Extracts JSON after [spellAiTemplateMarker], or the whole text if it is JSON.
String extractSpellAiTemplateJson(String clipboardText) {
  final text = clipboardText.trim();
  if (text.isEmpty) {
    throw SpellAiTemplateException('Clipboard is empty');
  }

  final markerIndex = text.indexOf(spellAiTemplateMarker);
  var jsonPart = markerIndex >= 0
      ? text.substring(markerIndex + spellAiTemplateMarker.length).trim()
      : text;

  // If the AI wrapped JSON in a fenced code block, unwrap it.
  if (jsonPart.startsWith('```')) {
    final lines = jsonPart.split('\n');
    if (lines.isNotEmpty) {
      lines.removeAt(0);
    }
    if (lines.isNotEmpty && lines.last.trim().startsWith('```')) {
      lines.removeLast();
    }
    jsonPart = lines.join('\n').trim();
  }

  if (jsonPart.isEmpty) {
    throw SpellAiTemplateException('No template JSON found on clipboard');
  }
  return jsonPart;
}

SpellAiTemplateData parseSpellAiTemplate({
  required String clipboardText,
  required List<CatalogItem> casterClasses,
  required List<CatalogItem> spellTags,
}) {
  final jsonText = extractSpellAiTemplateJson(clipboardText);
  late final Map<String, dynamic> map;
  try {
    final decoded = jsonDecode(jsonText);
    if (decoded is Map<String, dynamic>) {
      map = decoded;
    } else if (decoded is Map) {
      map = Map<String, dynamic>.from(decoded);
    } else {
      throw SpellAiTemplateException('Template JSON must be an object');
    }
  } on FormatException {
    throw SpellAiTemplateException('Template JSON is invalid');
  } on SpellAiTemplateException {
    rethrow;
  }

  final name = (map['name'] as String?)?.trim() ?? '';
  final level = _asInt(map['level'], field: 'level') ?? 0;
  if (level < 0 || level > 9) {
    throw SpellAiTemplateException('level must be 0–9');
  }

  final schoolRaw = (map['school'] as String?)?.trim().toLowerCase() ?? '';
  late final SpellSchool school;
  try {
    school = SpellSchool.values.byName(schoolRaw);
  } catch (_) {
    throw SpellAiTemplateException('Unknown school: ${map['school']}');
  }

  final casting = _asMap(map['castingTime'], field: 'castingTime');
  final castUnit =
      ((casting['unit'] as String?)?.trim().toLowerCase() ?? 'action');
  if (!spellAiCastingTimeUnits.contains(castUnit)) {
    throw SpellAiTemplateException('Unknown castingTime.unit: $castUnit');
  }
  final castAmount = _asInt(casting['amount'], field: 'castingTime.amount') ?? 1;
  if (castAmount < 1) {
    throw SpellAiTemplateException('castingTime.amount must be >= 1');
  }
  final reactionTrigger =
      (casting['reactionTrigger'] as String?)?.trim().nullIfEmpty;

  final range = _asMap(map['range'], field: 'range');
  final rangeType = ((range['type'] as String?)?.trim().toLowerCase() ?? 'self');
  final distanceFeet = _asInt(range['distanceFeet'], field: 'range.distanceFeet');
  final rangeKey = switch (rangeType) {
    'self' => 'self',
    'touch' => 'touch',
    'ranged' => () {
        if (distanceFeet == null ||
            !spellAiRangedDistances.contains(distanceFeet)) {
          throw SpellAiTemplateException(
            'range.distanceFeet must be one of $spellAiRangedDistances',
          );
        }
        return 'ranged:$distanceFeet';
      }(),
    _ => throw SpellAiTemplateException(
        'range.type must be self, touch, or ranged',
      ),
  };

  final components = _asMap(map['components'], field: 'components');
  final verbal = components['verbal'] as bool? ?? false;
  final somatic = components['somatic'] as bool? ?? false;
  final material = components['material'] as bool? ?? false;
  final materialDescription =
      (components['materialDescription'] as String?)?.trim().nullIfEmpty;
  final materialCostGp = _asDouble(
    components['materialCostGp'],
    field: 'components.materialCostGp',
  );
  final materialConsumed = components['materialConsumed'] as bool? ?? false;

  final duration = _asMap(map['duration'], field: 'duration');
  final durationTypeName =
      ((duration['type'] as String?)?.trim() ?? 'instantaneous');
  late final DurationType durationType;
  try {
    durationType = DurationType.values.byName(durationTypeName);
  } catch (_) {
    throw SpellAiTemplateException('Unknown duration.type: $durationTypeName');
  }
  final concentration = duration['concentration'] as bool? ?? false;
  final durationSpecial =
      (duration['special'] as String?)?.trim().nullIfEmpty;

  final classNames = _asStringList(map['classes'], field: 'classes');
  final tagNames = _asStringList(map['tags'], field: 'tags');
  final classIds = _resolveNamesToIds(
    names: classNames,
    items: casterClasses,
    label: 'class',
  );
  final tagIds = _resolveNamesToIds(
    names: tagNames,
    items: spellTags,
    label: 'tag',
  );

  final description = (map['description'] as String?) ?? '';
  final higherLevels = (map['higherLevels'] as String?) ?? '';
  final sourcePage = _asInt(map['sourcePage'], field: 'sourcePage');

  return SpellAiTemplateData(
    name: name,
    level: level,
    school: school,
    castAmount: castAmount,
    castUnit: castUnit,
    reactionTrigger: reactionTrigger,
    rangeKey: rangeKey,
    verbal: verbal,
    somatic: somatic,
    material: material,
    materialDescription: materialDescription,
    materialCostGp: materialCostGp,
    materialConsumed: materialConsumed,
    durationType: durationType,
    concentration: concentration,
    durationSpecial: durationSpecial,
    classIds: classIds,
    tagIds: tagIds,
    description: description,
    higherLevels: higherLevels,
    sourcePage: sourcePage,
  );
}

List<int> _resolveNamesToIds({
  required List<String> names,
  required List<CatalogItem> items,
  required String label,
}) {
  final byName = <String, CatalogItem>{
    for (final item in items) item.name.trim().toLowerCase(): item,
  };
  final missing = <String>[];
  final ids = <int>[];
  for (final name in names) {
    final key = name.trim().toLowerCase();
    if (key.isEmpty) continue;
    final item = byName[key];
    if (item == null) {
      missing.add(name.trim());
    } else {
      ids.add(item.id);
    }
  }
  if (missing.isNotEmpty) {
    throw SpellAiTemplateException(
      'Unknown $label${missing.length == 1 ? '' : 's'}: ${missing.join(', ')}',
    );
  }
  return ids;
}

Map<String, dynamic> _asMap(dynamic value, {required String field}) {
  if (value == null) return <String, dynamic>{};
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  throw SpellAiTemplateException('$field must be an object');
}

List<String> _asStringList(dynamic value, {required String field}) {
  if (value == null) return const [];
  if (value is! List) {
    throw SpellAiTemplateException('$field must be an array of strings');
  }
  return [
    for (final item in value)
      if (item is String)
        item
      else
        throw SpellAiTemplateException('$field must be an array of strings'),
  ];
}

int? _asInt(dynamic value, {required String field}) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) {
    final parsed = int.tryParse(value.trim());
    if (parsed != null) return parsed;
  }
  throw SpellAiTemplateException('$field must be an integer');
}

double? _asDouble(dynamic value, {required String field}) {
  if (value == null) return null;
  if (value is double) return value;
  if (value is num) return value.toDouble();
  if (value is String) {
    final parsed = double.tryParse(value.trim());
    if (parsed != null) return parsed;
  }
  throw SpellAiTemplateException('$field must be a number');
}

extension on String {
  String? get nullIfEmpty {
    final trimmed = trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
