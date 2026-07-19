import 'dart:typed_data';

import 'package:printing/printing.dart';

/// Web fallback when the print dialog is unavailable.
Future<void> presentPdfExportFallback(Uint8List pdfBytes) async {
  await Printing.sharePdf(
    bytes: pdfBytes,
    filename: 'spell_cards.pdf',
  );
}
