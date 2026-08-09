import 'package:flutter/material.dart';

/// Obsidian-like capped content width for Wikipedia-style article pages.
class WikiReadingWidth extends StatelessWidget {
  const WikiReadingWidth({
    super.key,
    required this.enabled,
    required this.child,
    this.maxWidth = defaultMaxWidth,
  });

  static const double defaultMaxWidth = 720;

  final bool enabled;
  final double maxWidth;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}

/// Shared Wikipedia-style page title: name + optional aliases (+ optional below).
class WikiArticleTitle extends StatelessWidget {
  const WikiArticleTitle({
    super.key,
    required this.name,
    this.aliases = const [],
    this.below = const [],
  });

  final String name;
  final List<String> aliases;

  /// Extra lines under aliases (e.g. session campaign link / date).
  final List<Widget> below;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final aliasLine = aliases
        .map((a) => a.trim())
        .where((a) => a.isNotEmpty)
        .join(', ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          name,
          style: textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        if (aliasLine.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            aliasLine,
            style: textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
        for (final child in below) ...[
          const SizedBox(height: 6),
          child,
        ],
      ],
    );
  }
}

/// Shared article shell: optional reading width, title, floated overview, body.
class WikiArticleLayout extends StatelessWidget {
  const WikiArticleLayout({
    super.key,
    required this.readableLineLength,
    required this.title,
    required this.bodyBuilder,
    this.overview,
    this.overviewWidth = 300,
    this.trailing = const [],
  });

  final bool readableLineLength;
  final Widget title;
  final Widget? overview;
  final double overviewWidth;

  /// Builds the main article body. [floatOverview] is non-null when the
  /// overview should be floated beside the prose (pass to
  /// [CatalogRichText.floatEnd]).
  final Widget Function(Widget? floatOverview) bodyBuilder;
  final List<Widget> trailing;

  /// Whether [overview] should float beside the body at [contentWidth].
  static bool shouldFloatOverview({
    required double contentWidth,
    required double overviewWidth,
    required bool hasOverview,
  }) {
    if (!hasOverview) return false;
    return contentWidth >= overviewWidth + 280;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxForContent = readableLineLength
            ? WikiReadingWidth.defaultMaxWidth
            : constraints.maxWidth;
        final contentWidth = constraints.maxWidth < maxForContent
            ? constraints.maxWidth
            : maxForContent;
        final float = shouldFloatOverview(
          contentWidth: contentWidth,
          overviewWidth: overviewWidth,
          hasOverview: overview != null,
        );

        return WikiReadingWidth(
          enabled: readableLineLength,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              title,
              if (!float && overview != null) ...[
                const SizedBox(height: 16),
                overview!,
              ],
              const SizedBox(height: 20),
              bodyBuilder(float ? overview : null),
              ...trailing,
            ],
          ),
        );
      },
    );
  }
}
