import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Which catalog kinds to extract.
enum ExtractRecordKind {
  spells,
  items,
  conditions,
}

extension ExtractRecordKindLabel on ExtractRecordKind {
  String get label => switch (this) {
        ExtractRecordKind.spells => 'Spells',
        ExtractRecordKind.items => 'Items',
        ExtractRecordKind.conditions => 'Conditions',
      };

  String get apiValue => switch (this) {
        ExtractRecordKind.spells => 'spells',
        ExtractRecordKind.items => 'items',
        ExtractRecordKind.conditions => 'conditions',
      };
}

class PdfPageRange {
  const PdfPageRange({
    required this.startPage,
    required this.endPage,
  });

  final int startPage;
  final int endPage;
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

/// Dialog to pick a page range only (for plain-text export).
Future<PdfPageRange?> showPdfPageRangeDialog({
  required BuildContext context,
  required int pageCount,
  String title = 'Export PDF text',
  String confirmLabel = 'Export',
}) {
  return showDialog<PdfPageRange>(
    context: context,
    builder: (context) => _PdfPageRangeDialog(
      pageCount: pageCount,
      title: title,
      confirmLabel: confirmLabel,
    ),
  );
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

String? validatePdfPageRange({
  required String startText,
  required String endText,
  required int pageCount,
}) {
  final start = int.tryParse(startText.trim());
  final end = int.tryParse(endText.trim());
  if (start == null || end == null) {
    return 'Enter valid page numbers';
  }
  if (start < 1 || end < 1) {
    return 'Pages start at 1';
  }
  if (start > pageCount || end > pageCount) {
    return 'This PDF has $pageCount pages';
  }
  if (start > end) {
    return 'Start page must be ≤ end page';
  }
  return null;
}

class _PageRangeFields extends StatelessWidget {
  const _PageRangeFields({
    required this.pageCount,
    required this.startController,
    required this.endController,
    required this.rangeError,
    required this.onChanged,
  });

  final int pageCount;
  final TextEditingController startController;
  final TextEditingController endController;
  final String? rangeError;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Pages (1–$pageCount)',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: startController,
                decoration: const InputDecoration(
                  labelText: 'From',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (_) => onChanged(),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Text('to'),
            ),
            Expanded(
              child: TextField(
                controller: endController,
                decoration: const InputDecoration(
                  labelText: 'To',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (_) => onChanged(),
              ),
            ),
          ],
        ),
        if (rangeError != null) ...[
          const SizedBox(height: 8),
          Text(
            rangeError!,
            style: TextStyle(
              color: Theme.of(context).colorScheme.error,
              fontSize: 12,
            ),
          ),
        ],
      ],
    );
  }
}

class _PdfPageRangeDialog extends StatefulWidget {
  const _PdfPageRangeDialog({
    required this.pageCount,
    required this.title,
    required this.confirmLabel,
  });

  final int pageCount;
  final String title;
  final String confirmLabel;

  @override
  State<_PdfPageRangeDialog> createState() => _PdfPageRangeDialogState();
}

class _PdfPageRangeDialogState extends State<_PdfPageRangeDialog> {
  late final TextEditingController _startController;
  late final TextEditingController _endController;
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
    setState(() {
      _rangeError = validatePdfPageRange(
        startText: _startController.text,
        endText: _endController.text,
        pageCount: widget.pageCount,
      );
    });
  }

  void _submit() {
    _validateRange();
    if (_rangeError != null) return;
    Navigator.of(context).pop(
      PdfPageRange(
        startPage: int.parse(_startController.text.trim()),
        endPage: int.parse(_endController.text.trim()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Choose pages to export as plain text for use with an external AI.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 16),
            _PageRangeFields(
              pageCount: widget.pageCount,
              startController: _startController,
              endController: _endController,
              rangeError: _rangeError,
              onChanged: _validateRange,
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
          onPressed: _rangeError == null ? _submit : null,
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
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
    setState(() {
      _rangeError = validatePdfPageRange(
        startText: _startController.text,
        endText: _endController.text,
        pageCount: widget.pageCount,
      );
    });
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
            _PageRangeFields(
              pageCount: widget.pageCount,
              startController: _startController,
              endController: _endController,
              rangeError: _rangeError,
              onChanged: _validateRange,
            ),
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
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(ExtractRecordKind.items.label),
              value: _kinds.contains(ExtractRecordKind.items),
              onChanged: (checked) {
                setState(() {
                  if (checked == true) {
                    _kinds.add(ExtractRecordKind.items);
                  } else {
                    _kinds.remove(ExtractRecordKind.items);
                  }
                });
              },
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(ExtractRecordKind.conditions.label),
              value: _kinds.contains(ExtractRecordKind.conditions),
              onChanged: (checked) {
                setState(() {
                  if (checked == true) {
                    _kinds.add(ExtractRecordKind.conditions);
                  } else {
                    _kinds.remove(ExtractRecordKind.conditions);
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
