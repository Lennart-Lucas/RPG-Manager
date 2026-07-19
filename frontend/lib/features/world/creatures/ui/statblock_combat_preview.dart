import 'package:flutter/material.dart';

import 'package:rpg_manager/features/world/creatures/data/creature_combat_snapshot.dart';

class StatblockCombatPreview extends StatelessWidget {
  const StatblockCombatPreview({required this.snapshot, super.key});

  final CreatureCombatSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Live Combat Preview', style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),
            _Section(
              title: 'Core Combat',
              rows: [
                ('Proficiency Bonus', '+${snapshot.proficiencyBonus}'),
                ('Armor Class', snapshot.armorClass.toString()),
                ('Hit Points', snapshot.hitPoints.toString()),
                ('Initiative', _signed(snapshot.initiativeBonus)),
                ('Attack Bonus', '+${snapshot.attackBonus}'),
                ('Attack DC', snapshot.attackDc.toString()),
                ('Attack Damage', snapshot.attackDamage.toString()),
                (
                  'Trained Saving Throws',
                  snapshot.trainedSavingThrows.toString(),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _Section(
              title: 'Ability Modifiers',
              rows: [
                ('Low', _signed(snapshot.abilityLow)),
                ('Mid', _signed(snapshot.abilityMid)),
                ('High', _signed(snapshot.abilityHigh)),
                ('STR', _signed(snapshot.attributeModifiers['STR'] ?? 0)),
                ('DEX', _signed(snapshot.attributeModifiers['DEX'] ?? 0)),
                ('CON', _signed(snapshot.attributeModifiers['CON'] ?? 0)),
                ('INT', _signed(snapshot.attributeModifiers['INT'] ?? 0)),
                ('WIS', _signed(snapshot.attributeModifiers['WIS'] ?? 0)),
                ('CHA', _signed(snapshot.attributeModifiers['CHA'] ?? 0)),
              ],
            ),
            const SizedBox(height: 12),
            _Section(
              title: 'Rank / Role Effects',
              rows: [
                ('Threat', snapshot.threatValue.toString()),
                ('Speed Modifier', _signed(snapshot.speedModifier)),
                ('Skill', snapshot.grantedSkill ?? 'None'),
                ('Other Features', snapshot.otherFeaturesGuidance),
              ],
            ),
            const SizedBox(height: 12),
            _Section(
              title: 'Trained Saves',
              rows: [
                (
                  'Attributes',
                  snapshot.trainedAttributes.isEmpty
                      ? 'None'
                      : snapshot.trainedAttributes.join(', '),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text('Special Features', style: theme.textTheme.titleMedium),
            const SizedBox(height: 6),
            if (snapshot.specialFeatures.isEmpty)
              Text('None', style: theme.textTheme.bodyMedium)
            else
              ...snapshot.specialFeatures.map(
                (feature) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text('- $feature', style: theme.textTheme.bodyMedium),
                ),
              ),
          ],
        ),
      ),
    );
  }

  static String _signed(int value) {
    if (value > 0) return '+$value';
    if (value < 0) return '$value';
    return '0';
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.rows});

  final String title;
  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: theme.textTheme.titleMedium),
        const SizedBox(height: 6),
        for (final row in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(row.$1, style: theme.textTheme.bodyMedium),
                ),
                const SizedBox(width: 8),
                Text(row.$2, style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
      ],
    );
  }
}
