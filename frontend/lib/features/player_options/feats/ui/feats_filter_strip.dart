import 'package:flutter/material.dart';

import '../../spells/ui/spells_filter_strip.dart';
import '../data/feat_list_filters.dart';

class FeatsFilterStrip extends StatelessWidget {
  const FeatsFilterStrip({
    required this.sectionBottomPadding,
    required this.sortModeSummary,
    required this.hasRequirementSummary,
    required this.onSortModeTap,
    required this.onHasRequirementTap,
    this.searchController,
    super.key,
  });

  final TextEditingController? searchController;
  final double sectionBottomPadding;
  final String sortModeSummary;
  final String hasRequirementSummary;
  final VoidCallback onSortModeTap;
  final VoidCallback onHasRequirementTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final barColor =
        theme.appBarTheme.backgroundColor ?? theme.scaffoldBackgroundColor;
    final search = searchController;
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
                  hintText: 'Name, requirement, or description',
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
              label: 'Requirement',
              summary: hasRequirementSummary,
              onTap: onHasRequirementTap,
              placeholder: FeatRequirementFilter.any.label,
              treatAnyAsPlaceholder: false,
            ),
          ],
        ),
      ),
    );
  }
}
