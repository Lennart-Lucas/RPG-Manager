import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:printing/printing.dart';

import 'card_export_present_io.dart'
    if (dart.library.html) 'card_export_present_web.dart';

const _pdfFileName = 'spell_cards.pdf';

/// Opens the system print / PDF UI when the platform supports it; otherwise
/// saves the file (desktop) or shares/downloads it (web).
Future<void> presentCardExportPdf(Uint8List pdfBytes) async {
  // Printing's native channel is often missing after hot restart; prefer a
  // full quit/relaunch for print UI. Always fall back to save/share.
  try {
    await Printing.layoutPdf(
      onLayout: (_) async => pdfBytes,
      name: _pdfFileName,
    );
    return;
  } on MissingPluginException catch (e) {
    debugPrint('printing plugin unavailable, using save dialog: $e');
  } catch (e) {
    debugPrint('Printing.layoutPdf failed, using save dialog: $e');
  }
  await presentPdfExportFallback(pdfBytes);
}
