import 'package:flutter/material.dart';

import '../../../dm_tools/resources/ui/resource_form_helpers.dart';

/// Multiline prompt + Process button for catalog AI fill.
///
/// Expands to fill available height when placed in a bounded parent (e.g.
/// [ResourceFormScaffold] with `scrollBody: false`).
class ClassAiProcessPane extends StatelessWidget {
  const ClassAiProcessPane({
    super.key,
    required this.controller,
    required this.processing,
    required this.onProcess,
    this.description =
        'Paste class text or describe changes. Process updates the Edit tab '
            'without saving.',
    this.hintText = 'Paste features text, or ask to rewrite wording…',
  });

  final TextEditingController controller;
  final bool processing;
  final VoidCallback onProcess;
  final String description;
  final String hintText;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          description,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: ResourceFormStyles.fieldSpacing),
        Expanded(
          child: TextField(
            controller: controller,
            enabled: !processing,
            maxLines: null,
            expands: true,
            textAlignVertical: TextAlignVertical.top,
            decoration: ResourceFormStyles.inputDecoration(
              context,
              label: 'Prompt / source text',
              hintText: hintText,
            ),
          ),
        ),
        const SizedBox(height: ResourceFormStyles.sectionSpacing),
        FilledButton(
          onPressed: processing ? null : onProcess,
          child: processing
              ? const SizedBox(
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Process'),
        ),
      ],
    );
  }
}
