import 'package:flutter/material.dart';

/// Curated Material icons for condition / damage-type records.
const kCatalogAppearanceIcons = <(String key, IconData icon, String label)>[
  ('favorite', Icons.favorite_outline, 'Heart'),
  ('monitor_heart', Icons.monitor_heart_outlined, 'Vital'),
  ('local_fire_department', Icons.local_fire_department_outlined, 'Fire'),
  ('ac_unit', Icons.ac_unit, 'Cold'),
  ('bolt', Icons.bolt_outlined, 'Lightning'),
  ('water_drop', Icons.water_drop_outlined, 'Acid'),
  ('toxic', Icons.science_outlined, 'Poison'),
  ('psychology', Icons.psychology_outlined, 'Psychic'),
  ('brightness_7', Icons.brightness_7_outlined, 'Radiant'),
  ('dark_mode', Icons.dark_mode_outlined, 'Necrotic'),
  ('hearing_disabled', Icons.hearing_disabled_outlined, 'Thunder'),
  ('landscape', Icons.landscape_outlined, 'Force'),
  ('coronavirus', Icons.coronavirus_outlined, 'Disease'),
  ('visibility_off', Icons.visibility_off_outlined, 'Blind'),
  ('volume_off', Icons.volume_off_outlined, 'Deaf'),
  ('sentiment_very_dissatisfied', Icons.sentiment_very_dissatisfied_outlined, 'Fear'),
  ('hourglass_empty', Icons.hourglass_empty, 'Slow'),
  ('lock', Icons.lock_outline, 'Restrain'),
  ('airline_seat_flat', Icons.airline_seat_flat, 'Prone'),
  ('flash_on', Icons.flash_on_outlined, 'Stun'),
  ('block', Icons.block, 'Paralyze'),
  ('spa', Icons.spa_outlined, 'Charm'),
  ('shield', Icons.shield_outlined, 'Shield'),
  ('swords', Icons.gavel_outlined, 'Weapon'),
  ('auto_awesome', Icons.auto_awesome_outlined, 'Magic'),
];

IconData catalogAppearanceIcon(String? key, {IconData fallback = Icons.circle_outlined}) {
  if (key == null || key.isEmpty) return fallback;
  for (final entry in kCatalogAppearanceIcons) {
    if (entry.$1 == key) return entry.$2;
  }
  return fallback;
}

Color catalogAppearanceColor(int? argb, {required Color fallback}) {
  if (argb == null) return fallback;
  return Color(argb);
}

int catalogAppearanceColorArgb(Color color) =>
    ((color.a * 255).round() << 24) |
    ((color.r * 255).round() << 16) |
    ((color.g * 255).round() << 8) |
    (color.b * 255).round();

const kCatalogAppearanceSwatches = <Color>[
  Color(0xFFE53935),
  Color(0xFFD81B60),
  Color(0xFF8E24AA),
  Color(0xFF5E35B1),
  Color(0xFF3949AB),
  Color(0xFF1E88E5),
  Color(0xFF039BE5),
  Color(0xFF00ACC1),
  Color(0xFF00897B),
  Color(0xFF43A047),
  Color(0xFF7CB342),
  Color(0xFFC0CA33),
  Color(0xFFFDD835),
  Color(0xFFFFB300),
  Color(0xFFFB8C00),
  Color(0xFFF4511E),
  Color(0xFF6D4C41),
  Color(0xFF546E7A),
  Color(0xFF78909C),
  Color(0xFF37474F),
];

class CatalogIconColorFields extends StatelessWidget {
  const CatalogIconColorFields({
    super.key,
    required this.iconKey,
    required this.colorArgb,
    required this.fallbackIcon,
    required this.onIconChanged,
    required this.onColorChanged,
  });

  final String iconKey;
  final int? colorArgb;
  final IconData fallbackIcon;
  final ValueChanged<String> onIconChanged;
  final ValueChanged<int?> onColorChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final selectedColor = catalogAppearanceColor(
      colorArgb,
      fallback: scheme.primary,
    );
    final selectedIcon = catalogAppearanceIcon(iconKey, fallback: fallbackIcon);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Icon', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final entry in kCatalogAppearanceIcons)
              InkWell(
                onTap: () => onIconChanged(entry.$1),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: iconKey == entry.$1
                        ? selectedColor.withValues(alpha: 0.22)
                        : scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: iconKey == entry.$1
                          ? selectedColor
                          : scheme.outlineVariant,
                    ),
                  ),
                  child: Icon(
                    entry.$2,
                    size: 20,
                    color: iconKey == entry.$1
                        ? selectedColor
                        : scheme.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Text('Color', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final swatch in kCatalogAppearanceSwatches)
              InkWell(
                onTap: () => onColorChanged(catalogAppearanceColorArgb(swatch)),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: swatch,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: colorArgb == catalogAppearanceColorArgb(swatch)
                          ? scheme.onSurface
                          : scheme.outlineVariant,
                      width: colorArgb == catalogAppearanceColorArgb(swatch)
                          ? 2.5
                          : 1,
                    ),
                  ),
                  child: colorArgb == catalogAppearanceColorArgb(swatch)
                      ? Icon(selectedIcon, size: 14, color: Colors.white)
                      : null,
                ),
              ),
          ],
        ),
      ],
    );
  }
}
