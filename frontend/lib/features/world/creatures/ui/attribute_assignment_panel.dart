import 'package:flutter/material.dart';

import 'package:rpg_manager/features/world/creatures/data/creature_model.dart';

class AttributeAssignmentPanel extends StatelessWidget {
  const AttributeAssignmentPanel({
    super.key,
    required this.assignments,
    required this.slotModifiers,
    required this.trainedAttributes,
    required this.trainedSavingThrows,
    required this.onSwapRequested,
    required this.onToggleTrained,
  });

  final Map<AbilityKey, String> assignments;
  final Map<String, int> slotModifiers;
  final Set<AbilityKey> trainedAttributes;
  final int trainedSavingThrows;
  final void Function(AbilityKey attribute, AbilityKey selectedAttribute)
      onSwapRequested;
  final void Function(AbilityKey attribute) onToggleTrained;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isOverTrained = trainedAttributes.length > trainedSavingThrows;
    return Row(
      children: [
        for (var i = 0; i < AbilityKey.values.length; i++) ...[
          Expanded(
            child: _AttributeBox(
              attribute: AbilityKey.values[i],
              currentSlot: assignments[AbilityKey.values[i]]!,
              currentModifier:
                  slotModifiers[assignments[AbilityKey.values[i]]] ?? 0,
              assignments: assignments,
              isTrained: trainedAttributes.contains(AbilityKey.values[i]),
              isOverTrained: isOverTrained,
              backgroundColor: colors.secondaryContainer,
              foregroundColor: colors.onSecondaryContainer,
              onAttributeSelected: (selectedAttribute) => onSwapRequested(
                AbilityKey.values[i],
                selectedAttribute,
              ),
              onLongPress: () => onToggleTrained(AbilityKey.values[i]),
            ),
          ),
          if (i != AbilityKey.values.length - 1) const SizedBox(width: 8),
        ],
      ],
    );
  }
}

class _AttributeBox extends StatelessWidget {
  const _AttributeBox({
    required this.attribute,
    required this.currentSlot,
    required this.currentModifier,
    required this.assignments,
    required this.isTrained,
    required this.isOverTrained,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.onAttributeSelected,
    required this.onLongPress,
  });

  final AbilityKey attribute;
  final String currentSlot;
  final int currentModifier;
  final Map<AbilityKey, String> assignments;
  final bool isTrained;
  final bool isOverTrained;
  final Color backgroundColor;
  final Color foregroundColor;
  final void Function(AbilityKey selectedAttribute) onAttributeSelected;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final statValue = 10 + (2 * currentModifier);
    final modifierText =
        currentModifier >= 0 ? '+$currentModifier' : '$currentModifier';
    final effectiveBackground = isTrained
        ? (isOverTrained ? colors.errorContainer : colors.primaryContainer)
        : backgroundColor;
    final effectiveForeground = isTrained
        ? (isOverTrained ? colors.onErrorContainer : colors.onPrimaryContainer)
        : foregroundColor;

    return GestureDetector(
      onLongPress: onLongPress,
      child: PopupMenuButton<AbilityKey>(
        borderRadius: BorderRadius.circular(10),
        onSelected: onAttributeSelected,
        itemBuilder: (context) => [
          for (final option in AbilityKey.values)
            if (option != attribute)
              PopupMenuItem<AbilityKey>(
                value: option,
                child: Text(
                  '${option.label} (${_slotLabel(assignments[option])})',
                ),
              ),
        ],
        child: Material(
          color: effectiveBackground,
          borderRadius: BorderRadius.circular(10),
          clipBehavior: Clip.antiAlias,
          child: SizedBox(
            width: double.infinity,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    attribute.label,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: effectiveForeground,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$statValue ($modifierText)',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: effectiveForeground,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _slotLabel(String? slot) {
    if (slot == null) return 'Unknown';
    if (slot.startsWith('high')) return 'High';
    if (slot.startsWith('medium')) return 'Mid';
    return 'Low';
  }
}
