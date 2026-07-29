import 'package:flutter/material.dart';

import '../data/character_model.dart';

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
          Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Color(color.colorArgb),
              shape: BoxShape.circle,
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            child: Text(
              color.label,
              style: TextStyle(
                color: Color(color.onColorArgb),
                fontWeight: FontWeight.w800,
                fontSize: size * 0.42,
              ),
            ),
          ),
      ],
    );
  }
}
