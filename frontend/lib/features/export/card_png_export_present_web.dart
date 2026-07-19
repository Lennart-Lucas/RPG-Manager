import 'dart:typed_data';

import 'package:printing/printing.dart';

/// Web: triggers a download via the printing plugin.
Future<void> presentCardPngExportImpl(
  Uint8List pngBytes,
  String fileName,
) async {
  await Printing.sharePdf(bytes: pngBytes, filename: fileName);
}
