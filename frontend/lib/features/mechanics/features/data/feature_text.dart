import 'feature_ep.dart';
import 'feature_model.dart';

String durationLabel(FeatureEffectDuration d) => switch (d) {
      FeatureEffectDuration.instant => 'Instant',
      FeatureEffectDuration.concentration => 'Concentration (up to 1 minute)',
      FeatureEffectDuration.ongoing => 'Ongoing',
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
    if (range.feet != null) {
      parts.add(
        '${range.mode.distanceLabel.toLowerCase()} ${range.feet} ft.',
      );
    } else {
      parts.add(range.mode.label);
    }
    final t = feature.targets;
    if (t.quantity != FeatureTargetQuantity.none) {
      final qty = switch (t.quantity) {
        FeatureTargetQuantity.one => 'one',
        FeatureTargetQuantity.limited => '<limited>',
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
    effectBits.add(
      _effectText(
        effect,
        scalerDmg: scalerDmg,
        targetQuantity: feature.targets.quantity,
      ),
    );
  }

  final header = parts.isEmpty ? null : parts.join('; ');
  final body = effectBits.join(' ');
  if (header != null && body.isNotEmpty) return '$header. $body';
  if (header != null) return '$header.';
  if (body.isNotEmpty) return body;
  return feature.text;
}

String _effectText(
  FeatureEffect effect, {
  int? scalerDmg,
  FeatureTargetQuantity targetQuantity = FeatureTargetQuantity.one,
}) {
  final dur = effect.duration == FeatureEffectDuration.instant
      ? ''
      : ' (${durationLabel(effect.duration)})';
  final p = effect.payload;
  switch (effect.type) {
    case FeatureEffectType.damage:
      final ep = (p['damageEp'] as num?)?.toInt() ?? 1;
      final damageOnMiss = p['damageOnMiss'] == true &&
          targetQuantity == FeatureTargetQuantity.all;
      final pct = damagePercents(
        ep: ep,
        quantity: targetQuantity,
        damageOnMiss: damageOnMiss,
      );
      final types = (p['damageTypes'] as List?)?.join(', ') ?? 'damage';
      final perTarget = targetQuantity == FeatureTargetQuantity.limited
          ? ' / target'
          : '';
      if (scalerDmg != null) {
        final hit = ((scalerDmg * pct.hitPercent) / 100).round();
        if (damageOnMiss) {
          final miss = ((scalerDmg * pct.missPercent) / 100).round();
          return 'Hit: $hit $types damage; Miss: $miss$dur.';
        }
        return 'Hit: $hit$perTarget $types damage$dur.';
      }
      if (damageOnMiss) {
        return 'Hit: ${pct.hitPercent}% $types damage; '
            'Miss: ${pct.missPercent}%$dur.';
      }
      return 'Hit: ${pct.hitPercent}%$perTarget $types damage$dur.';
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
