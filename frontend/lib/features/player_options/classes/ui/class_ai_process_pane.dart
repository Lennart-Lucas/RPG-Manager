import 'package:flutter/material.dart';

import '../../../dm_tools/resources/ui/resource_form_helpers.dart';

/// Multline prompt + Process button for class/subclass AI fill.
class ClassAiProcessPane extends StatelessWidget {
  const ClassAiProcessPane({
    super.key,
    required this.controller,
    required this.processing,
    required this.onProcess,
  });

  final TextEditingController controller;
  final bool processing;
  final VoidCallback onProcess;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Paste class text or describe changes. Process updates the Edit tab '
          'without saving.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: ResourceFormStyles.fieldSpacing),
        TextField(
          controller: controller,
          enabled: !processing,
          minLines: 10,
          maxLines: 20,
          decoration: ResourceFormStyles.inputDecoration(
            context,
            label: 'Prompt / source text',
            hintText: 'Paste features text, or ask to rewrite wording…',
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
