import 'package:flutter/material.dart';

import 'package:rpg_manager/features/world/creatures/data/creature_model.dart';
import 'package:rpg_manager/features/world/creatures/data/scaler_math.dart'; // ScalerRoleLabel

class CreatureStatblockView extends StatelessWidget {
  const CreatureStatblockView({required this.creature, super.key});

  final Creature creature;

  String _mod(int score) {
    if (score >= 0) return '+$score';
    return '$score';
  }

  String _speedLine(ScalerComputedStats formula) {
    final parts = <String>[];
    final walk = creature.speeds.walk + formula.speedWalkDelta;
    parts.add('$walk ft.');
    if (creature.speeds.fly != null) parts.add('fly ${creature.speeds.fly} ft.');
    if (creature.speeds.swim != null) {
      parts.add('swim ${creature.speeds.swim} ft.');
    }
    if (creature.speeds.climb != null) {
      parts.add('climb ${creature.speeds.climb} ft.');
    }
    if (creature.speeds.burrow != null) {
      parts.add('burrow ${creature.speeds.burrow} ft.');
    }
    return parts.join(', ');
  }

  String _attackLine() {
    final parts = <String>['ATK ${_mod(creature.atk)}', 'DC ${creature.dc}'];
    parts.add('DMG ${creature.dmg}');
    if (creature.reach != null) parts.add('reach ${creature.reach} ft.');
    if (creature.range != null) parts.add('range ${creature.range} ft.');
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final formula = creature.formula;
    final scores = creature.abilityScores;
    const saveKeys = ['str', 'dex', 'con', 'int', 'wis', 'cha'];
    const saveLabels = ['STR', 'DEX', 'CON', 'INT', 'WIS', 'CHA'];
    final trained = creature.trainedSavingThrows.map((s) => s.toLowerCase()).toSet();

    final typeLine = [
      creature.size,
      if (creature.creatureType.isNotEmpty) creature.creatureType,
    ].join(' ');

    final roleLine = [
      'Level ${creature.level}',
      creature.rankDisplay,
      if (creature.role != null) creature.role!.label,
      if (creature.roleSubtype != null) creature.roleSubtype,
    ].join(' · ');

    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              creature.name.trim().isEmpty ? 'Creature' : creature.name,
              style: textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            if (typeLine.trim().isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                typeLine,
                style: textTheme.titleSmall?.copyWith(
                  fontStyle: FontStyle.italic,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 4),
            Text(roleLine, style: textTheme.bodyMedium),
            const Divider(height: 24),
            _StatLine(label: 'Armor Class', value: '${creature.ac}'),
            _StatLine(
              label: 'Hit Points',
              value:
                  '${creature.hp} (bloodied ${creature.bloodied}, enraged ${creature.enraged})',
            ),
            _StatLine(label: 'Speed', value: _speedLine(formula)),
            _StatLine(
              label: 'Initiative',
              value: _mod(creature.initiativeBonus),
            ),
            const SizedBox(height: 12),
            _AbilityRow(scores: scores, mod: _mod),
            const SizedBox(height: 12),
            if (trained.isNotEmpty)
              _StatLine(
                label: 'Saving Throws',
                value: [
                  for (var i = 0; i < saveKeys.length; i++)
                    if (trained.contains(saveKeys[i]))
                      '${saveLabels[i]} ${_mod(scores[AbilityKey.values[i]] + creature.proficiencyBonus)}',
                ].join(', '),
              ),
            if (creature.skills.isNotEmpty)
              _StatLine(label: 'Skills', value: creature.skills.join(', ')),
            if (creature.senses.isNotEmpty)
              _StatLine(label: 'Senses', value: creature.senses.join(', ')),
            _StatLine(
              label: 'Passive Perception',
              value: '${creature.passivePerception}',
            ),
            if (creature.languages.isNotEmpty)
              _StatLine(label: 'Languages', value: creature.languages.join(', ')),
            if (creature.vulnerabilities.isNotEmpty)
              _StatLine(
                label: 'Vulnerabilities',
                value: creature.vulnerabilities.join(', '),
              ),
            if (creature.resistances.isNotEmpty)
              _StatLine(
                label: 'Resistances',
                value: creature.resistances.join(', '),
              ),
            if (creature.immunities.isNotEmpty)
              _StatLine(
                label: 'Immunities',
                value: creature.immunities.join(', '),
              ),
            const SizedBox(height: 8),
            _StatLine(
              label: 'Challenge',
              value: 'CR ${creature.cr} (${creature.xp} XP)',
            ),
            const SizedBox(height: 4),
            Text(_attackLine(), style: textTheme.bodyMedium),
            if (creature.features.isNotEmpty) ...[
              const Divider(height: 24),
              Text(
                'Features',
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              for (final entry in creature.features)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.displayName,
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(entry.displayText, style: textTheme.bodyMedium),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatLine extends StatelessWidget {
  const _StatLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: RichText(
        text: TextSpan(
          style: textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
          ),
          children: [
            TextSpan(
              text: '$label ',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}

class _AbilityRow extends StatelessWidget {
  const _AbilityRow({required this.scores, required this.mod});

  final CreatureAbilityScores scores;
  final String Function(int score) mod;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final entries = [
      ('STR', scores.str),
      ('DEX', scores.dex),
      ('CON', scores.con),
      ('INT', scores.int_),
      ('WIS', scores.wis),
      ('CHA', scores.cha),
    ];
    return Wrap(
      spacing: 12,
      runSpacing: 4,
      children: [
        for (final (label, score) in entries)
          Text(
            '$label ${mod(score)}',
            style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
      ],
    );
  }
}
