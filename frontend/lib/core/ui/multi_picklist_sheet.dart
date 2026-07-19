import 'package:flutter/material.dart';

/// One row in [showMultiPicklistSheet] — [id] is stored in the selection set.
class PicklistOption {
  const PicklistOption({required this.id, required this.label});

  final String id;
  final String label;
}

/// Multi-select from [options] (checkbox list).
Future<Set<String>?> showMultiPicklistSheet(
  BuildContext context, {
  required String title,
  required List<PicklistOption> options,
  required Set<String> selected,
}) async {
  final working = Set<String>.from(selected);
  return showModalBottomSheet<Set<String>>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) {
      final maxHeight = MediaQuery.sizeOf(ctx).height * 0.7;
      return SafeArea(
        child: StatefulBuilder(
          builder: (ctx, setModalState) {
            return SizedBox(
              height: maxHeight,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      child: Text(
                        title,
                        style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: options.length,
                        itemBuilder: (context, index) {
                          final opt = options[index];
                          return CheckboxListTile(
                            value: working.contains(opt.id),
                            onChanged: (v) {
                              setModalState(() {
                                if (v == true) {
                                  working.add(opt.id);
                                } else {
                                  working.remove(opt.id);
                                }
                              });
                            },
                            title: Text(opt.label),
                            controlAffinity: ListTileControlAffinity.leading,
                          );
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          TextButton(
                            onPressed: () {
                              setModalState(() => working.clear());
                            },
                            child: const Text('Clear selection'),
                          ),
                          const Spacer(),
                          FilledButton(
                            onPressed: () => Navigator.of(ctx).pop(working),
                            child: const Text('Done'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );
    },
  );
}
