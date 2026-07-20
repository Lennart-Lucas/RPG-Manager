import 'package:pdfrx/pdfrx.dart';

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
  Future<String> extractFromFile(
    String absolutePath, {
    int? startPage,
    int? endPage,
  }) async {
    final document = await PdfDocument.openFile(absolutePath);
    try {
      final pageCount = document.pages.length;
      if (pageCount == 0) return '';

      final first = (startPage ?? 1).clamp(1, pageCount);
      final last = (endPage ?? pageCount).clamp(first, pageCount);

      final buffer = StringBuffer();
      for (var pageNumber = first; pageNumber <= last; pageNumber++) {
        final page = document.pages[pageNumber - 1];
        final pageText = await page.loadText();
        final fullText = pageText?.fullText ?? '';
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
      return buffer.toString().trim();
    } finally {
      await document.dispose();
    }
  }
}
