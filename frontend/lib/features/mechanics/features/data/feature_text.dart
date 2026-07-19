import 'feature_ep.dart';
import 'feature_model.dart';

String durationLabel(FeatureEffectDuration d) => switch (d) {
      FeatureEffectDuration.instant => 'Instant',
      FeatureEffectDuration.endOfYourNextTurn => 'until the end of your next turn',
      FeatureEffectDuration.endOfTargetNextTurn =>
        "until the end of the target's next turn",
      FeatureEffectDuration.concentration => 'Concentration (up to 1 minute)',
      FeatureEffectDuration.ongoing => 'Ongoing',
      FeatureEffectDuration.saveEnds => 'Save Ends',
    };

/// Deterministic rules text from structured feature fields.
String generateFeatureText(
  MonsterFeature feature, {
  int? scalerDmg,
}) {
  final parts = <String>[];

  if (feature.limitation.type != FeatureLimitationType.none) {
    final lim = feature.limitation;
    switch (lim.type) {
      case FeatureLimitationType.charges:
        parts.add(
          '${lim.value ?? "1"} charge${lim.value == "1" ? "" : "s"}'
          '${lim.recoveryTrigger != null ? " (recovers on ${lim.recoveryTrigger})" : ""}',
        );
      case FeatureLimitationType.recharge:
        parts.add('Recharge ${lim.value ?? "5-6"}');
      case FeatureLimitationType.cooldown:
        parts.add('Cooldown ${lim.value ?? "3"}');
      case FeatureLimitationType.recoveryEvent:
        parts.add(
          'Recovery: ${lim.recoveryTrigger ?? lim.value ?? "long rest"}',
        );
      case FeatureLimitationType.none:
        break;
    }
  }

  if (feature.activationTime != FeatureActivation.none &&
      feature.activationTime != FeatureActivation.action) {
    parts.add(feature.activationTime.label);
  }

  if (feature.category != FeatureCategory.trait) {
    final def = feature.defence;
    if (def != null) {
      parts.add('Save/Attack vs ${def.label}');
    }
    final range = feature.range;
    if (range.category != FeatureRangeCategory.self) {
      final dist = [
        if (range.template.isNotEmpty) range.template,
        if (range.distance.isNotEmpty) range.distance,
      ].join(' ');
      parts.add(dist.isEmpty ? range.category.name : dist);
    }
    final t = feature.targets;
    if (t.quantity != FeatureTargetQuantity.none) {
      final qty = switch (t.quantity) {
        FeatureTargetQuantity.one => 'one',
        FeatureTargetQuantity.limited => '${t.limitedCount ?? 2}',
        FeatureTargetQuantity.all => 'all',
        FeatureTargetQuantity.none => '',
      };
      parts.add('$qty ${t.category.name}');
    }
  }

  if (feature.deferral.isActive) {
    parts.add(
      '${feature.deferral.type.name} (${feature.deferral.turns ?? "N"} turns)',
    );
  }

  final effectBits = <String>[];
  for (final effect in feature.effects) {
    effectBits.add(_effectText(effect, scalerDmg: scalerDmg));
  }

  final header = parts.isEmpty ? null : parts.join('; ');
  final body = effectBits.join(' ');
  if (header != null && body.isNotEmpty) return '$header. $body';
  if (header != null) return '$header.';
  if (body.isNotEmpty) return body;
  return feature.text;
}

String _effectText(FeatureEffect effect, {int? scalerDmg}) {
  final dur = effect.duration == FeatureEffectDuration.instant
      ? ''
      : ' (${durationLabel(effect.duration)})';
  final p = effect.payload;
  switch (effect.type) {
    case FeatureEffectType.damage:
      final ep = (p['damageEp'] as num?)?.toInt() ?? 1;
      final modeName = p['delivery'] as String? ?? 'area';
      final mode = switch (modeName) {
        'aimedSingle' => DamageDeliveryMode.aimedSingle,
        'aimedMulti' => DamageDeliveryMode.aimedMulti,
        _ => DamageDeliveryMode.area,
      };
      final pct = damagePercents(ep: ep, mode: mode);
      final types = (p['damageTypes'] as List?)?.join(', ') ?? 'damage';
      if (scalerDmg != null) {
        final hit = ((scalerDmg * pct.hitPercent) / 100).round();
        if (mode == DamageDeliveryMode.area) {
          final miss = ((scalerDmg * pct.missPercent) / 100).round();
          return 'Hit: $hit $types damage; Miss: $miss$dur.';
        }
        return 'Hit: $hit $types damage$dur.';
      }
      if (mode == DamageDeliveryMode.area) {
        return 'Hit: ${pct.hitPercent}% $types damage; Miss: ${pct.missPercent}%$dur.';
      }
      return 'Hit: ${pct.hitPercent}% $types damage$dur.';
    case FeatureEffectType.condition:
      final name = p['condition'] as String? ?? 'a condition';
      return 'The target is $name$dur.';
    case FeatureEffectType.terrain:
      final name = p['modifier'] as String? ?? 'altered';
      return 'Terrain becomes $name$dur.';
    case FeatureEffectType.resource:
      final name = p['resource'] as String? ?? 'a resource';
      return 'Destroy/remove $name$dur.';
    case FeatureEffectType.movement:
      final ep = (p['movementEp'] as num?)?.toInt() ?? 1;
      final kind = p['movementKind'] as String? ?? 'push';
      final mode = DamageDeliveryMode.aimedSingle;
      final ft = movementFeet(ep: ep, mode: mode, onHit: true);
      return '$kind the target $ft ft$dur.';
    case FeatureEffectType.empower:
      final name = p['boon'] as String? ?? 'a boon';
      return 'Grant $name$dur.';
  }
}
