import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Which catalog kinds to extract. Only [spells] is supported today.
enum ExtractRecordKind {
  spells,
}

extension ExtractRecordKindLabel on ExtractRecordKind {
  String get label => switch (this) {
        ExtractRecordKind.spells => 'Spells',
      };
}

class ExtractJobOptions {
  const ExtractJobOptions({
    required this.startPage,
    required this.endPage,
    required this.kinds,
  });

  final int startPage;
  final int endPage;
  final Set<ExtractRecordKind> kinds;
}

/// Dialog to pick page range and record kinds before running extract.
Future<ExtractJobOptions?> showExtractOptionsDialog({
  required BuildContext context,
  required int pageCount,
}) {
  return showDialog<ExtractJobOptions>(
    context: context,
    builder: (context) => _ExtractOptionsDialog(pageCount: pageCount),
  );
}

class _ExtractOptionsDialog extends StatefulWidget {
  const _ExtractOptionsDialog({required this.pageCount});

  final int pageCount;

  @override
  State<_ExtractOptionsDialog> createState() => _ExtractOptionsDialogState();
}

class _ExtractOptionsDialogState extends State<_ExtractOptionsDialog> {
  late final TextEditingController _startController;
  late final TextEditingController _endController;
  final Set<ExtractRecordKind> _kinds = {ExtractRecordKind.spells};
  String? _rangeError;

  @override
  void initState() {
    super.initState();
    _startController = TextEditingController(text: '1');
    _endController = TextEditingController(text: '${widget.pageCount}');
  }

  @override
  void dispose() {
    _startController.dispose();
    _endController.dispose();
    super.dispose();
  }

  void _validateRange() {
    final start = int.tryParse(_startController.text.trim());
    final end = int.tryParse(_endController.text.trim());
    String? error;
    if (start == null || end == null) {
      error = 'Enter valid page numbers';
    } else if (start < 1 || end < 1) {
      error = 'Pages start at 1';
    } else if (start > widget.pageCount || end > widget.pageCount) {
      error = 'This PDF has ${widget.pageCount} pages';
    } else if (start > end) {
      error = 'Start page must be ≤ end page';
    }
    setState(() => _rangeError = error);
  }

  void _submit() {
    _validateRange();
    if (_rangeError != null || _kinds.isEmpty) return;
    final start = int.parse(_startController.text.trim());
    final end = int.parse(_endController.text.trim());
    Navigator.of(context).pop(
      ExtractJobOptions(
        startPage: start,
        endPage: end,
        kinds: Set<ExtractRecordKind>.from(_kinds),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canSubmit = _rangeError == null && _kinds.isNotEmpty;

    return AlertDialog(
      title: const Text('Extract from PDF'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Pages (1–${widget.pageCount})',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _startController,
                    decoration: const InputDecoration(
                      labelText: 'From',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (_) => _validateRange(),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Text('to'),
                ),
                Expanded(
                  child: TextField(
                    controller: _endController,
                    decoration: const InputDecoration(
                      labelText: 'To',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (_) => _validateRange(),
                  ),
                ),
              ],
            ),
            if (_rangeError != null) ...[
              const SizedBox(height: 8),
              Text(
                _rangeError!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 12,
                ),
              ),
            ],
            const SizedBox(height: 20),
            Text(
              'Import',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            Text(
              'Choose which record types to extract.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 8),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(ExtractRecordKind.spells.label),
              subtitle: const Text('Supported'),
              value: _kinds.contains(ExtractRecordKind.spells),
              onChanged: (checked) {
                setState(() {
                  if (checked == true) {
                    _kinds.add(ExtractRecordKind.spells);
                  } else {
                    _kinds.remove(ExtractRecordKind.spells);
                  }
                });
              },
            ),
            if (_kinds.isEmpty)
              Text(
                'Select at least one record type',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 12,
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: canSubmit ? _submit : null,
          child: const Text('Extract'),
        ),
      ],
    );
  }
}
