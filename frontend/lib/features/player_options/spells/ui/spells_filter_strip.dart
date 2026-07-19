import 'package:flutter/material.dart';

/// Filter form used by the Spells page.
class SpellsFilterStrip extends StatelessWidget {
  const SpellsFilterStrip({
    required this.sectionBottomPadding,
    required this.sortModeSummary,
    required this.schoolSummary,
    required this.levelSummary,
    required this.spellTagsSummary,
    required this.classesSummary,
    required this.damageTypesSummary,
    required this.conditionsSummary,
    required this.castingTypeSummary,
    required this.concentrationSummary,
    required this.onSortModeTap,
    required this.onSchoolTap,
    required this.onLevelTap,
    required this.onSpellTagsTap,
    required this.onClassesTap,
    required this.onDamageTypesTap,
    required this.onConditionsTap,
    required this.onCastingTypeTap,
    required this.onConcentrationTap,
    this.spellSearchController,
    super.key,
  });

  final TextEditingController? spellSearchController;
  final double sectionBottomPadding;
  final String sortModeSummary;
  final String schoolSummary;
  final String levelSummary;
  final String spellTagsSummary;
  final String classesSummary;
  final String damageTypesSummary;
  final String conditionsSummary;
  final String castingTypeSummary;
  final String concentrationSummary;
  final VoidCallback onSortModeTap;
  final VoidCallback onSchoolTap;
  final VoidCallback onLevelTap;
  final VoidCallback onSpellTagsTap;
  final VoidCallback onClassesTap;
  final VoidCallback onDamageTypesTap;
  final VoidCallback onConditionsTap;
  final VoidCallback onCastingTypeTap;
  final VoidCallback onConcentrationTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final barColor =
        theme.appBarTheme.backgroundColor ?? theme.scaffoldBackgroundColor;
    final search = spellSearchController;
    final hasSearch = search != null && search.text.trim().isNotEmpty;
    return Material(
      color: barColor,
      elevation: 1,
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 8, 16, sectionBottomPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (search != null) ...[
              TextField(
                controller: search,
                decoration: InputDecoration(
                  labelText: 'Search',
                  hintText: 'Name or description',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: hasSearch
                      ? IconButton(
                          tooltip: 'Clear search',
                          icon: const Icon(Icons.close),
                          onPressed: search.clear,
                        )
                      : null,
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                textInputAction: TextInputAction.search,
              ),
              const SizedBox(height: 12),
            ],
            SpellsFilterMultiSelectField(
              label: 'Sort',
              summary: sortModeSummary,
              onTap: onSortModeTap,
              placeholder: 'Tap to choose sort…',
              treatAnyAsPlaceholder: false,
            ),
            const SizedBox(height: 12),
            SpellsFilterMultiSelectField(
              label: 'Classes',
              summary: classesSummary,
              onTap: onClassesTap,
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: SpellsFilterMultiSelectField(
                    label: 'Level',
                    summary: levelSummary,
                    onTap: onLevelTap,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SpellsFilterMultiSelectField(
                    label: 'School',
                    summary: schoolSummary,
                    onTap: onSchoolTap,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SpellsFilterMultiSelectField(
              label: 'Spell tags',
              summary: spellTagsSummary,
              onTap: onSpellTagsTap,
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: SpellsFilterMultiSelectField(
                    label: 'Casting type',
                    summary: castingTypeSummary,
                    onTap: onCastingTypeTap,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SpellsFilterMultiSelectField(
                    label: 'Concentration',
                    summary: concentrationSummary,
                    onTap: onConcentrationTap,
                    treatAnyAsPlaceholder: false,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: SpellsFilterMultiSelectField(
                    label: 'Conditions',
                    summary: conditionsSummary,
                    onTap: onConditionsTap,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SpellsFilterMultiSelectField(
                    label: 'Damage types',
                    summary: damageTypesSummary,
                    onTap: onDamageTypesTap,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class SpellsFilterMultiSelectField extends StatelessWidget {
  const SpellsFilterMultiSelectField({
    required this.label,
    required this.summary,
    required this.onTap,
    this.placeholder = _defaultPlaceholder,
    this.treatAnyAsPlaceholder = true,
    super.key,
  });

  final String label;
  final String summary;
  final VoidCallback onTap;
  final String placeholder;
  final bool treatAnyAsPlaceholder;

  static const _defaultPlaceholder = 'Tap to choose…';

  @override
  Widget build(BuildContext context) {
    final hintStyle = TextStyle(color: Theme.of(context).hintColor);
    final isAny = treatAnyAsPlaceholder && summary == 'Any';
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            children: [
              Expanded(
                child: isAny
                    ? Text(placeholder, style: hintStyle)
                    : Text(
                        summary,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
              ),
              Icon(
                Icons.arrow_drop_down,
                color: Theme.of(context).hintColor,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
