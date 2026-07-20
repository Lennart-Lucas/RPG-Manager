import 'package:pdfrx/pdfrx.dart';

/// Extract plain text from a local PDF with page markers for the extract API.
class PdfTextExtractor {
  /// Returns text with `\n\n--- page N ---\n\n` markers (1-based).
  Future<String> extractFromFile(String absolutePath) async {
    final document = await PdfDocument.openFile(absolutePath);
    try {
      final buffer = StringBuffer();
      for (var i = 0; i < document.pages.length; i++) {
        final pageNumber = i + 1;
        final page = document.pages[i];
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
