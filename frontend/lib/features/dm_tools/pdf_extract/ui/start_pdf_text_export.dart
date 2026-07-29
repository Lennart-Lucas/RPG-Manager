import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../resources/data/local_resource_file_copy.dart';
import '../../resources/data/resource_models.dart';
import '../data/pdf_text_extractor.dart';
import 'extract_options_dialog.dart';

String _defaultTxtFileName(String fileName, int startPage, int endPage) {
  final base = fileName.trim().isEmpty ? 'export' : fileName.trim();
  final withoutExt = base.toLowerCase().endsWith('.pdf')
      ? base.substring(0, base.length - 4)
      : base;
  final sanitized = withoutExt
      .replaceAll(RegExp(r'[^\w\s\-]'), '')
      .replaceAll(RegExp(r'\s+'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');
  final stem = sanitized.isEmpty ? 'export' : sanitized;
  return '${stem}_p$startPage-$endPage.txt';
}

/// Extracts PDF text for a page range, copies to clipboard, and offers Save.
Future<void> startPdfTextExport({
  required BuildContext context,
  required ResourceFile file,
  required String localPath,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final extractor = PdfTextExtractor();
  final fileCopy = LocalResourceFileCopy();

  int pageCount;
  try {
    pageCount = await extractor.pageCount(localPath);
  } catch (e) {
    messenger.showSnackBar(
      SnackBar(content: Text('Could not open PDF: $e')),
    );
    return;
  }
  if (pageCount < 1) {
    messenger.showSnackBar(
      const SnackBar(content: Text('This PDF has no pages')),
    );
    return;
  }

  if (!context.mounted) return;
  final range = await showPdfPageRangeDialog(
    context: context,
    pageCount: pageCount,
  );
  if (range == null || !context.mounted) return;

  final progressMessage = ValueNotifier<String>(
    'Exporting text from pages ${range.startPage}–${range.endPage}…',
  );
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      content: Row(
        children: [
          const CircularProgressIndicator(),
          const SizedBox(width: 20),
          Expanded(
            child: ValueListenableBuilder<String>(
              valueListenable: progressMessage,
              builder: (context, message, _) => Text(message),
            ),
          ),
        ],
      ),
    ),
  );

  try {
    final text = await extractor.extractFromFile(
      localPath,
      startPage: range.startPage,
      endPage: range.endPage,
      onProgress: ({required page, required endPage, required usedOcr}) {
        final mode = usedOcr ? 'OCR' : 'text';
        progressMessage.value =
            'Reading page $page of $endPage ($mode)…';
      },
    );
    if (!context.mounted) return;
    Navigator.of(context, rootNavigator: true).pop();

    if (!pdfExportHasBodyText(text)) {
      messenger.showSnackBar(
        const SnackBar(content: Text(kPdfNoExtractableTextMessage)),
      );
      return;
    }

    await Clipboard.setData(ClipboardData(text: text));

    if (!context.mounted) return;
    final defaultName = _defaultTxtFileName(
      file.name,
      range.startPage,
      range.endPage,
    );
    final savePath = await FilePicker.platform.saveFile(
      dialogTitle: 'Save PDF text',
      fileName: defaultName,
      type: FileType.custom,
      allowedExtensions: const ['txt'],
    );

    if (savePath == null) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Copied ${text.length} characters '
            '(pages ${range.startPage}–${range.endPage})',
          ),
        ),
      );
      return;
    }

    final target =
        savePath.toLowerCase().endsWith('.txt') ? savePath : '$savePath.txt';
    await File(target).writeAsString(text, flush: true);

    try {
      await fileCopy.openLocalPath(target);
    } catch (_) {
      // Opening is best-effort; clipboard + save already succeeded.
    }

    messenger.showSnackBar(
      SnackBar(
        content: Text(
          'Copied ${text.length} characters and saved '
          '${target.split(Platform.pathSeparator).last}',
        ),
      ),
    );
  } catch (e) {
    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
    }
    messenger.showSnackBar(
      SnackBar(content: Text('Text export failed: $e')),
    );
  }
}
