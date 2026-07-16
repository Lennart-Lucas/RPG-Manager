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

Future<T?> showAdaptiveResourceForm<T>(
  BuildContext context, {
  required String title,
  required Widget child,
}) {
  final width = MediaQuery.sizeOf(context).width;
  final compact = width < 720;
  if (compact) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => _ResourceFormScaffold(
        title: title,
        compact: true,
        child: child,
      ),
    );
  }
  return showDialog<T>(
    context: context,
    builder: (context) => Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640, maxHeight: 760),
        child: _ResourceFormScaffold(
          title: title,
          compact: false,
          child: child,
        ),
      ),
    ),
  );
}

class _ResourceFormScaffold extends StatelessWidget {
  const _ResourceFormScaffold({
    required this.title,
    required this.compact,
    required this.child,
  });

  final String title;
  final bool compact;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
        top: !compact,
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
            const Divider(height: 1),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                child: child,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
