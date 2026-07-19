import 'dart:io' show File;
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

/// Saves [pdfBytes] using a native save dialog (desktop / mobile IO).
Future<void> presentPdfExportFallback(Uint8List pdfBytes) async {
  final path = await FilePicker.platform.saveFile(
    dialogTitle: 'Save spell cards',
    fileName: 'spell_cards.pdf',
    type: FileType.custom,
    allowedExtensions: ['pdf'],
  );
  if (path == null) return;
  final target = path.toLowerCase().endsWith('.pdf') ? path : '$path.pdf';
  await File(target).writeAsBytes(pdfBytes);
}
