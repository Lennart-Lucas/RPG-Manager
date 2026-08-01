import 'package:flutter/material.dart';

import '../data/character_model.dart';
import 'mtg_mana_symbol.dart';

class MtgAlignmentChips extends StatelessWidget {
  const MtgAlignmentChips({
    super.key,
    required this.colors,
    this.size = 28,
  });

  final List<MtgColor> colors;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (colors.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final color in colors)
          Tooltip(
            message: color.displayName,
            child: MtgManaSymbol(color: color, size: size),
          ),
      ],
    );
  }
}
