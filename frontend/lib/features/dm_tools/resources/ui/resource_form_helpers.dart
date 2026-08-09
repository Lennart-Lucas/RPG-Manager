import 'package:flutter/material.dart';

class ResourceFormStyles {
  ResourceFormStyles._();

  static const double fieldSpacing = 12;
  static const double sectionSpacing = 20;

  static InputDecoration inputDecoration(
    BuildContext context, {
    required String label,
    String? hintText,
    String? helperText,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final base = Theme.of(context).inputDecorationTheme;
    final outline = OutlineInputBorder(
      borderRadius: BorderRadius.circular(4),
      borderSide: BorderSide(color: scheme.outline),
    );
    final focused = OutlineInputBorder(
      borderRadius: BorderRadius.circular(4),
      borderSide: BorderSide(color: scheme.primary, width: 2),
    );
    final error = OutlineInputBorder(
      borderRadius: BorderRadius.circular(4),
      borderSide: BorderSide(color: scheme.error),
    );
    final focusedError = OutlineInputBorder(
      borderRadius: BorderRadius.circular(4),
      borderSide: BorderSide(color: scheme.error, width: 2),
    );

    return InputDecoration(
      labelText: label,
      hintText: hintText,
      helperText: helperText,
      filled: base.filled,
      fillColor: base.fillColor,
      border: outline,
      enabledBorder: outline,
      focusedBorder: focused,
      errorBorder: error,
      focusedErrorBorder: focusedError,
      disabledBorder: outline.copyWith(
        borderSide: BorderSide(
          color: scheme.onSurface.withValues(alpha: 0.38),
        ),
      ),
      contentPadding: base.contentPadding ??
          const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      isDense: base.isDense,
    );
  }
}

/// Adaptive dialog / bottom-sheet host for a prebuilt [ResourceFormScaffold]
/// (or any full form chrome widget).
Future<T?> showAdaptiveResourceFormHost<T>(
  BuildContext context, {
  required WidgetBuilder builder,
}) {
  final width = MediaQuery.sizeOf(context).width;
  final compact = width < 720;
  if (compact) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: builder,
    );
  }
  return showDialog<T>(
    context: context,
    builder: (context) => Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640, maxHeight: 760),
        child: builder(context),
      ),
    ),
  );
}

Future<T?> showAdaptiveResourceForm<T>(
  BuildContext context, {
  required String title,
  required Widget child,
}) {
  final compact = MediaQuery.sizeOf(context).width < 720;
  return showAdaptiveResourceFormHost<T>(
    context,
    builder: (context) => ResourceFormScaffold(
      title: title,
      compact: compact,
      child: child,
    ),
  );
}

class ResourceFormScaffold extends StatelessWidget {
  const ResourceFormScaffold({
    super.key,
    required this.title,
    required this.compact,
    required this.child,
    this.headerTabs,
    this.scrollBody = true,
  });

  final String title;
  final bool compact;
  final Widget child;
  final Widget? headerTabs;

  /// When false (and [headerTabs] is set), the body fills remaining height
  /// without an outer scroll view so children can expand (e.g. Process pane).
  final bool scrollBody;

  static const double dialogHeight = 760;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    // Keep a stable frame when header tabs are present so switching panes
    // does not resize the dialog / sheet.
    final fillHeight = headerTabs != null;
    final sheetHeight = MediaQuery.sizeOf(context).height * 0.92;
    const bodyPadding = EdgeInsets.fromLTRB(20, 20, 20, 20);

    Widget paddedBody;
    if (fillHeight && !scrollBody) {
      paddedBody = Padding(padding: bodyPadding, child: child);
    } else {
      paddedBody = SingleChildScrollView(
        padding: bodyPadding,
        child: child,
      );
    }

    final body = Column(
      mainAxisSize: fillHeight ? MainAxisSize.max : MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
              IconButton(
                tooltip: 'Close',
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
        ),
        ?headerTabs,
        const Divider(height: 1),
        if (fillHeight)
          Expanded(child: paddedBody)
        else
          Flexible(child: paddedBody),
      ],
    );

    final frameHeight = compact ? sheetHeight : dialogHeight;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: fillHeight ? 0 : bottomInset),
      child: SafeArea(
        top: !compact,
        child: fillHeight
            ? SizedBox(
                height: (frameHeight - bottomInset).clamp(280.0, frameHeight),
                child: body,
              )
            : body,
      ),
    );
  }
}
