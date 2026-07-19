import 'dart:io' show File;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:printing/printing.dart';

Future<void> presentCardPngExportImpl(
  Uint8List pngBytes,
  String fileName,
) async {
  try {
    await Printing.sharePdf(bytes: pngBytes, filename: fileName);
    return;
  } on MissingPluginException catch (_) {
    // e.g. Linux desktop without `printing` native implementation registered.
  }
  final path = await FilePicker.platform.saveFile(
    dialogTitle: 'Save card image',
    fileName: fileName,
    type: FileType.custom,
    allowedExtensions: ['png'],
  );
  if (path == null) return;
  final target = path.toLowerCase().endsWith('.png') ? path : '$path.png';
  await File(target).writeAsBytes(pngBytes);
}
