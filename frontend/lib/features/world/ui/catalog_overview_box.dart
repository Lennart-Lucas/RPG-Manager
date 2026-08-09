import 'package:flutter/material.dart';

import '../../../core/ui/catalog_image_slot.dart';
import '../../auth/state/auth_controller.dart';
import 'overview_sections.dart';
import 'overview_sections_view.dart';

/// Shared Wikipedia-style overview shell: title, aliases, image, optional
/// leading content, then [OverviewSectionsView].
class CatalogOverviewBox extends StatelessWidget {
  const CatalogOverviewBox({
    super.key,
    required this.auth,
    required this.title,
    required this.icon,
    this.aliases = const [],
    this.imageUrl = '',
    this.leading = const [],
    this.overviewSections = const [],
    this.trailing = const [],
  });

  final AuthController auth;
  final String title;
  final IconData icon;
  final List<String> aliases;
  final String imageUrl;

  /// Extra widgets between the image and overview sections (e.g. chips).
  final List<Widget> leading;

  final List<OverviewSection> overviewSections;

  /// Extra widgets after overview sections.
  final List<Widget> trailing;

  static const double preferredWidth = 300;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    Color lift(Color toward, double amount) =>
        Color.lerp(scheme.surface, toward, amount)!;

    final panelBg = lift(scheme.onSurface, 0.07);
    final borderColor = scheme.outline.withValues(alpha: 0.55);
    final hasSections = overviewSectionsNonEmpty(overviewSections);

    return Material(
      color: panelBg,
      elevation: 1,
      shadowColor: scheme.shadow.withValues(alpha: 0.35),
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: borderColor),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainer,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: borderColor),
                    ),
                    child: Icon(
                      icon,
                      color: scheme.onSurfaceVariant,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: textTheme.titleMedium?.copyWith(
                            color: scheme.onSurface,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (aliases.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            aliases.join(', '),
                            style: textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, thickness: 1, color: borderColor),
            Padding(
              padding: const EdgeInsets.all(14),
              child: CatalogImageSlot(
                imageUrl: imageUrl,
                borderColor: borderColor,
                placeholder: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      icon,
                      size: 40,
                      color: scheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Image placeholder',
                      style: textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      title,
                      style: textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
            for (final child in leading) child,
            if (hasSections)
              OverviewSectionsView(
                auth: auth,
                sections: overviewSections,
              ),
            for (final child in trailing) child,
          ],
        ),
      ),
    );
  }
}
