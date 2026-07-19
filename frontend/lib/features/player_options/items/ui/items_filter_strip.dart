import 'package:flutter/material.dart';

import '../../spells/ui/spells_filter_strip.dart';

class ItemsFilterStrip extends StatelessWidget {
  const ItemsFilterStrip({
    required this.sectionBottomPadding,
    required this.sortModeSummary,
    required this.typeSummary,
    required this.raritySummary,
    required this.magicOnly,
    required this.attunementOnly,
    required this.onSortModeTap,
    required this.onTypeTap,
    required this.onRarityTap,
    required this.onMagicOnlyChanged,
    required this.onAttunementOnlyChanged,
    this.searchController,
    super.key,
  });

  final TextEditingController? searchController;
  final double sectionBottomPadding;
  final String sortModeSummary;
  final String typeSummary;
  final String raritySummary;
  final bool magicOnly;
  final bool attunementOnly;
  final VoidCallback onSortModeTap;
  final VoidCallback onTypeTap;
  final VoidCallback onRarityTap;
  final ValueChanged<bool> onMagicOnlyChanged;
  final ValueChanged<bool> onAttunementOnlyChanged;

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
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: SpellsFilterMultiSelectField(
                    label: 'Type',
                    summary: typeSummary,
                    onTap: onTypeTap,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SpellsFilterMultiSelectField(
                    label: 'Rarity',
                    summary: raritySummary,
                    onTap: onRarityTap,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: const Text('Magic only'),
                    value: magicOnly,
                    onChanged: onMagicOnlyChanged,
                  ),
                ),
                Expanded(
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: const Text('Attunement only'),
                    value: attunementOnly,
                    onChanged: onAttunementOnlyChanged,
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
