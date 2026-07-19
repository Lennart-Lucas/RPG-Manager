import 'dart:typed_data';

import 'card_png_export_present_io.dart'
    if (dart.library.html) 'card_png_export_present_web.dart';

/// Sanitized single-segment filename (caller should add extension).
String cardExportSafeBaseName(String name) {
  final base = name.trim().isEmpty ? 'card' : name;
  return base.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
}

/// Shares or saves [pngBytes] as [fileName] (should end in `.png`).
Future<void> presentCardPngExport(Uint8List pngBytes, String fileName) =>
    presentCardPngExportImpl(pngBytes, fileName);
