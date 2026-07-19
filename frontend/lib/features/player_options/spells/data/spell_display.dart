import 'spell_model.dart';

String spellLevelOrdinal(int n) {
  if (n >= 11 && n <= 13) return '${n}th';
  switch (n % 10) {
    case 1:
      return '${n}st';
    case 2:
      return '${n}nd';
    case 3:
      return '${n}rd';
    default:
      return '${n}th';
  }
}

String spellLevelDisplayName(int level) {
  if (level == 0) return 'Cantrip';
  return spellLevelOrdinal(level);
}

/// Display helpers for spell list cards and MTG detail sheets.
extension SpellDisplay on Spell {
  String get levelDisplayName => spellLevelDisplayName(level);

  String get listSubtitle => '$levelDisplayName · ${school.label}';

  String get componentsAbbrev {
    final parts = <String>[
      if (components.verbal) 'V',
      if (components.somatic) 'S',
      if (components.material) 'M',
    ];
    return parts.isEmpty ? 'None' : parts.join(', ');
  }

  String get componentsCardLine {
    final base = componentsAbbrev;
    final mat = components.materialDescription?.trim() ?? '';
    if (components.material && mat.isNotEmpty) {
      return '$base ($mat)';
    }
    return base;
  }

  String get castingAndRangeLine {
    final unit = castingTime.unit.trim();
    var casting = '${castingTime.amount} $unit'.trim();
    final trig = castingTime.reactionTrigger?.trim() ?? '';
    if (unit.toLowerCase().contains('reaction') && trig.isNotEmpty) {
      casting = '$casting ($trig)';
    }
    return '$casting · ${range.label}';
  }

  /// Compact duration for list cards (v3-style `(C)` marker).
  String get durationListDisplay {
    final base = duration.type == DurationType.special
        ? (duration.special ?? 'Special')
        : duration.type.label;
    if (!isConcentration) return base;
    if (duration.type == DurationType.instantaneous) {
      return '$base (C)';
    }
    return 'Up to $base (C)';
  }

  String get durationCardDisplay => durationListDisplay;

  String get rulesContent {
    final desc = description.trim();
    final fh = higherLevels?.description?.trim() ?? '';
    final fhBlock = fh.isEmpty ? '' : '**At Higher Levels:** $fh';
    if (fhBlock.isEmpty) return desc;
    if (desc.isEmpty) return fhBlock;
    return '$desc\n$fhBlock';
  }

  /// Normalized casting-type code for filters.
  String get castingTypeCode {
    final unit = castingTime.unit.trim().toLowerCase();
    if (unit.contains('bonus')) return 'bonus_action';
    if (unit.contains('reaction')) return 'reaction';
    if (unit.contains('minute')) return 'minute';
    if (unit.contains('hour')) return 'hour';
    if (unit == 'action' || unit.contains('action')) return 'action';
    return unit.replaceAll(' ', '_');
  }

  String get castingTypeLabel {
    return switch (castingTypeCode) {
      'action' => 'Action',
      'bonus_action' => 'Bonus Action',
      'reaction' => 'Reaction',
      'minute' => 'Minute(s)',
      'hour' => 'Hour(s)',
      _ => castingTime.unit,
    };
  }
}
