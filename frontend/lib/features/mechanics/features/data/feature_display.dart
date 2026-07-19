import 'package:flutter/painting.dart';

import 'feature_model.dart';

String joinWithAndOr(List<String> parts) {
  final cleaned = [
    for (final p in parts)
      if (p.trim().isNotEmpty) p.trim(),
  ];
  if (cleaned.isEmpty) return '';
  if (cleaned.length == 1) return cleaned.first;
  if (cleaned.length == 2) return '${cleaned[0]} and/or ${cleaned[1]}';
  return '${cleaned.sublist(0, cleaned.length - 1).join(', ')}, '
      'and/or ${cleaned.last}';
}

/// Structured display values for a feature, rendered as styled rules text.
class FeatureDisplay {
  const FeatureDisplay({
    required this.name,
    this.category = FeatureCategory.trait,
    this.rulesText = '',
    this.atk,
    this.dc,
    this.defence,
    this.delivery = FeatureDelivery.weapon,
    this.rangeMode = FeatureRangeMode.melee,
    this.rangeFeet,
    this.targetQuantity = FeatureTargetQuantity.none,
    this.targetCategory = FeatureTargetCategory.target,
    this.targetAlliance = FeatureTargetAlliance.any,
    this.creatureTypeNames = const [],
  });

  final String name;
  final FeatureCategory category;
  final String rulesText;
  final int? atk;
  final int? dc;
  final FeatureDefence? defence;
  final FeatureDelivery delivery;
  final FeatureRangeMode rangeMode;
  final int? rangeFeet;
  final FeatureTargetQuantity targetQuantity;
  final FeatureTargetCategory targetCategory;
  final FeatureTargetAlliance targetAlliance;
  final List<String> creatureTypeNames;

  factory FeatureDisplay.fromFeature(
    MonsterFeature feature, {
    int? atk,
    int? dc,
    Map<int, String> creatureTypeNamesById = const {},
  }) =>
      FeatureDisplay(
        name: feature.name,
        category: feature.category,
        rulesText: feature.text,
        atk: atk,
        dc: dc,
        defence: feature.defence,
        delivery: feature.delivery,
        rangeMode: feature.range.mode,
        rangeFeet: feature.range.feet,
        targetQuantity: feature.targets.quantity,
        targetCategory: feature.targets.category,
        targetAlliance: feature.targets.alliance,
        creatureTypeNames: [
          for (final id in feature.targets.creatureTypeIds)
            ?creatureTypeNamesById[id],
        ],
      );

  bool get _isTrait => category == FeatureCategory.trait;

  bool get _usesDc =>
      defence != null && defence != FeatureDefence.ac;

  /// "Melee" / "Ranged" for the attack line (picklist may say "Range").
  String get _rangeKindLabel => switch (rangeMode) {
        FeatureRangeMode.melee => 'Melee',
        FeatureRangeMode.ranged => 'Ranged',
      };

  String get _deliveryLabel => delivery.label;

  String get _offenseLabel {
    if (_usesDc) {
      return dc == null ? '<DC>' : 'DC $dc';
    }
    return atk == null ? '<ATK>' : (atk! >= 0 ? '+$atk' : '$atk');
  }

  String get _distanceKindLabel => switch (rangeMode) {
        FeatureRangeMode.melee => 'reach',
        FeatureRangeMode.ranged => 'range',
      };

  String get _feetLabel => rangeFeet == null ? '<range>' : '$rangeFeet';

  String _categoryWord({required bool plural}) {
    if (targetCategory == FeatureTargetCategory.self) return 'self';
    return switch (targetCategory) {
      FeatureTargetCategory.target => plural ? 'targets' : 'target',
      FeatureTargetCategory.object => plural ? 'objects' : 'object',
      FeatureTargetCategory.creature => plural ? 'creatures' : 'creature',
      FeatureTargetCategory.self => 'self',
    };
  }

  String get _typeFilterLabel {
    final joined = joinWithAndOr([
      for (final name in creatureTypeNames) name.toLowerCase(),
    ]);
    return joined.isEmpty ? '' : '$joined ';
  }

  String get _targetLabel {
    if (targetCategory == FeatureTargetCategory.self) return 'self';
    final useCreatureFilters =
        targetCategory == FeatureTargetCategory.creature;
    final alliance =
        useCreatureFilters ? targetAlliance.displayWord : null;
    final allianceBit = alliance == null ? '' : '$alliance ';
    final typesBit = useCreatureFilters ? _typeFilterLabel : '';
    switch (targetQuantity) {
      case FeatureTargetQuantity.none:
        return '<target>';
      case FeatureTargetQuantity.one:
        return 'one $allianceBit$typesBit${_categoryWord(plural: false)}';
      case FeatureTargetQuantity.limited:
        return '<limited> $allianceBit$typesBit${_categoryWord(plural: true)}';
      case FeatureTargetQuantity.all:
        return 'all $allianceBit$typesBit${_categoryWord(plural: true)}';
    }
  }

  String get _rulesTextLabel {
    final trimmed = rulesText.trim();
    return trimmed.isEmpty ? '<Rules text>' : trimmed;
  }

  String get _attackLine =>
      '. $_rangeKindLabel $_deliveryLabel Attack: '
      '$_offenseLabel to hit, $_distanceKindLabel $_feetLabel ft., '
      '$_targetLabel.';

  /// Styled rules text. Expand as more fields are wired into the preview.
  InlineSpan toSpan({TextStyle? style}) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      return TextSpan(text: '', style: style);
    }
    return TextSpan(
      style: style,
      children: [
        TextSpan(
          text: trimmed,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        TextSpan(
          text: _isTrait ? '. $_rulesTextLabel' : _attackLine,
        ),
      ],
    );
  }
}
