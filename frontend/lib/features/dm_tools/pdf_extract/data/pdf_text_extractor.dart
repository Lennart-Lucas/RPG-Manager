import 'package:pdfrx/pdfrx.dart';

import 'vision_ocr.dart';

final _pageMarkerPattern = RegExp(
  r'---\s*page\s+\d+\s*---',
  caseSensitive: false,
);

/// Whether [text] contains anything besides page markers / whitespace.
bool pdfExportHasBodyText(String text) {
  return text.replaceAll(_pageMarkerPattern, '').trim().isNotEmpty;
}

const kPdfNoExtractableTextMessage =
    'No extractable text in this page range. '
    'The PDF may be image-only, and OCR found nothing (or is unavailable).';

/// Called while extracting; [page] and [endPage] are 1-based inclusive.
typedef PdfExtractProgress = void Function({
  required int page,
  required int endPage,
  required bool usedOcr,
});

/// Extract plain text from a local PDF with page markers for the extract API.
class PdfTextExtractor {
  /// Returns the number of pages in [absolutePath].
  Future<int> pageCount(String absolutePath) async {
    final document = await PdfDocument.openFile(absolutePath);
    try {
      return document.pages.length;
    } finally {
      await document.dispose();
    }
  }

  /// Returns text with `\n\n--- page N ---\n\n` markers (1-based).
  ///
  /// [startPage] and [endPage] are inclusive, 1-based. Defaults to the full
  /// document when omitted.
  ///
  /// When a page has no PDF text layer, falls back to Apple Vision OCR on
  /// macOS (same approach Preview uses for image-only PDFs).
  Future<String> extractFromFile(
    String absolutePath, {
    int? startPage,
    int? endPage,
    PdfExtractProgress? onProgress,
    bool enableOcrFallback = true,
  }) async {
    final document = await PdfDocument.openFile(absolutePath);
    try {
      final pageCount = document.pages.length;
      if (pageCount == 0) return '';

      final first = (startPage ?? 1).clamp(1, pageCount);
      final last = (endPage ?? pageCount).clamp(first, pageCount);

      final ocrAvailable =
          enableOcrFallback && await VisionOcr.isAvailable();

      final buffer = StringBuffer();
      var bodyChars = 0;
      for (var pageNumber = first; pageNumber <= last; pageNumber++) {
        final page = document.pages[pageNumber - 1];
        final pageText = await page.loadText();
        var fullText = pageText?.fullText ?? '';
        var usedOcr = false;

        if (fullText.replaceAll(RegExp(r'\s'), '').isEmpty && ocrAvailable) {
          usedOcr = true;
          fullText = await _ocrPage(page);
        }

        bodyChars += fullText.replaceAll(RegExp(r'\s'), '').length;
        onProgress?.call(page: pageNumber, endPage: last, usedOcr: usedOcr);

        if (buffer.isNotEmpty) {
          buffer.writeln();
        }
        buffer.writeln('--- page $pageNumber ---');
        buffer.writeln();
        buffer.write(fullText.trimRight());
        if (!fullText.endsWith('\n')) {
          buffer.writeln();
        }
      }
      final out = buffer.toString().trim();
      if (bodyChars == 0 || !pdfExportHasBodyText(out)) {
        return '';
      }
      return out;
    } finally {
      await document.dispose();
    }
  }

  Future<String> _ocrPage(PdfPage page) async {
    // Match native page pixel size (~72 dpi); Vision handled this well in probes.
    final fullWidth = page.width;
    final fullHeight = page.height;
    final rendered = await page.render(
      fullWidth: fullWidth,
      fullHeight: fullHeight,
    );
    if (rendered == null) return '';
    try {
      return await VisionOcr.recognizeBgra(
        pixels: rendered.pixels,
        width: rendered.width,
        height: rendered.height,
      );
    } finally {
      rendered.dispose();
    }
  }
}
