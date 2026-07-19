import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'local_resource_file_copy.dart';

/// Exception thrown when an AnyFlip download cannot complete.
class AnyFlipDownloaderException implements Exception {
  AnyFlipDownloaderException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Downloads an AnyFlip book as a PDF on the desktop client.
///
/// Protocol inspired by
/// [anyflip-downloader](https://github.com/Lofter1/anyflip-downloader)
/// (config.js + page images → PDF). Reimplemented in Dart; no external CLI.
class AnyFlipDownloader {
  AnyFlipDownloader({http.Client? httpClient})
      : _client = httpClient ?? http.Client();

  final http.Client _client;

  static const _userAgent = 'Mozilla/5.0';
  static const _maxParallel = 4;
  static const _retries = 2;
  static const _retryDelay = Duration(seconds: 1);

  /// Downloads [url] to a temp directory and returns the absolute PDF path.
  Future<String> downloadPdf(String url, {String? preferredTitle}) async {
    if (!isDesktopFileStorageSupported) {
      throw AnyFlipDownloaderException(
        'AnyFlip download is only available on desktop.',
      );
    }

    final trimmed = url.trim();
    final bookUri = _sanitizeBookUrl(trimmed);
    final config = await _fetchConfigJs(bookUri);

    final parsedTitle = _parseBookTitle(config);
    final title = _safeTitle(
      preferredTitle?.trim().isNotEmpty == true
          ? preferredTitle!.trim()
          : (parsedTitle ?? _titleFromUrl(bookUri)),
    );

    final pageCount = _parsePageCount(config);
    if (pageCount <= 0) {
      throw AnyFlipDownloaderException('Could not determine page count.');
    }

    final fileNames = _parsePageFileNames(config);
    final pageUrls = _buildPageUrls(
      bookUri: bookUri,
      pageCount: pageCount,
      fileNames: fileNames,
    );

    final workDir = await Directory.systemTemp.createTemp('anyflip_');
    try {
      final images = await _downloadPages(
        pageUrls: pageUrls,
        referer: bookUri.toString(),
      );
      if (images.isEmpty) {
        throw AnyFlipDownloaderException('No pages could be downloaded.');
      }

      final pdfPath = p.join(workDir.path, '$title.pdf');
      await _writePdf(pdfPath, images);
      return pdfPath;
    } on AnyFlipDownloaderException {
      rethrow;
    } catch (error) {
      throw AnyFlipDownloaderException('AnyFlip download failed: $error');
    }
  }

  Uri _sanitizeBookUrl(String raw) {
    final uri = Uri.tryParse(raw);
    if (uri == null ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.host.isEmpty) {
      throw AnyFlipDownloaderException('Enter a valid AnyFlip URL.');
    }
    final segments =
        uri.pathSegments.where((s) => s.trim().isNotEmpty).toList();
    if (segments.length < 2) {
      throw AnyFlipDownloaderException(
        'AnyFlip URL must include publisher and book path segments.',
      );
    }
    return Uri(
      scheme: 'https',
      host: 'online.anyflip.com',
      path: '/${segments[0]}/${segments[1]}',
    );
  }

  Future<String> _fetchConfigJs(Uri bookUri) async {
    final configUri = bookUri.replace(
      path: '${bookUri.path}/mobile/javascript/config.js',
    );
    final response = await _client.get(configUri);
    if (response.statusCode != 200) {
      throw AnyFlipDownloaderException(
        'Could not load book config (${response.statusCode}).',
      );
    }
    return response.body;
  }

  String? _parseBookTitle(String configjs) {
    final match = RegExp(
      r'''("?(?:bookConfig\.)?bookTitle"?\s*=\s*"(.*?)")|"title"\s*:\s*"(.*?)"''',
    ).firstMatch(configjs);
    if (match == null) return null;
    final fromAssign = match.group(2);
    final fromJson = match.group(3);
    final title = (fromAssign ?? fromJson)?.trim();
    return (title == null || title.isEmpty) ? null : title;
  }

  int _parsePageCount(String configjs) {
    final match = RegExp(
      r'''"?(?:bookConfig\.)?(?:total)?[Pp]ageCount"?\s*[=:]\s*"?(\d+)"?''',
    ).firstMatch(configjs);
    if (match == null) {
      throw AnyFlipDownloaderException('Could not find page count in config.');
    }
    return int.parse(match.group(1)!);
  }

  List<String> _parsePageFileNames(String configjs) {
    final names = <String>[];
    for (final match in RegExp(r'"n"\s*:\s*\[(.*?)\]', dotAll: true)
        .allMatches(configjs)) {
      final body = match.group(1);
      if (body == null) continue;
      for (final nameMatch in RegExp(r'"([^"]+)"').allMatches(body)) {
        final name = nameMatch.group(1)?.trim();
        if (name != null && name.isNotEmpty) {
          names.add(_unescapeJsPath(name));
        }
      }
    }
    return names;
  }

  /// Config.js stores paths with JS escapes (e.g. `..\/files\/mobile\/1.webp`).
  String _unescapeJsPath(String raw) {
    return raw.replaceAll(r'\/', '/').replaceAll(r'\\', r'\');
  }

  List<String> _buildPageUrls({
    required Uri bookUri,
    required int pageCount,
    required List<String> fileNames,
  }) {
    if (fileNames.isEmpty) {
      return [
        for (var i = 1; i <= pageCount; i++)
          _absoluteOnlinePath('${bookUri.path}/files/mobile/$i.jpg'),
      ];
    }
    final count = pageCount < fileNames.length ? pageCount : fileNames.length;
    return [
      for (var i = 0; i < count; i++)
        // Match upstream: join under files/large, then resolve ".." and
        // dedupe consecutive segments (files/files → files).
        _cleanDownloadUrl(
          p.url.join(bookUri.path, 'files', 'large', fileNames[i]),
        ),
    ];
  }

  String _absoluteOnlinePath(String path) {
    return Uri(
      scheme: 'https',
      host: 'online.anyflip.com',
      path: path,
    ).toString();
  }

  /// Resolve `..` / `.` and remove consecutive duplicate path segments.
  String _cleanDownloadUrl(String rawPath) {
    var path = rawPath.replaceAll(r'\', '/');
    path = p.url.normalize(path);
    final segments = path.split('/');
    final deduped = <String>[];
    for (var i = 0; i < segments.length; i++) {
      final seg = segments[i];
      if (i > 0 && seg.isNotEmpty && seg == segments[i - 1]) {
        continue;
      }
      deduped.add(seg);
    }
    return _absoluteOnlinePath(deduped.join('/'));
  }

  Future<List<Uint8List>> _downloadPages({
    required List<String> pageUrls,
    required String referer,
  }) async {
    final results = List<Uint8List?>.filled(pageUrls.length, null);
    var nextIndex = 0;

    Future<void> worker() async {
      while (true) {
        final index = nextIndex;
        nextIndex++;
        if (index >= pageUrls.length) return;
        results[index] = await _downloadPage(
          pageUrls[index],
          referer: referer,
        );
      }
    }

    final workers = [
      for (var i = 0; i < _maxParallel; i++) worker(),
    ];
    await Future.wait(workers);

    final images = <Uint8List>[];
    for (var i = 0; i < results.length; i++) {
      final bytes = results[i];
      if (bytes == null || bytes.isEmpty) {
        throw AnyFlipDownloaderException('Failed to download page ${i + 1}.');
      }
      images.add(bytes);
    }
    return images;
  }

  Future<Uint8List> _downloadPage(
    String url, {
    required String referer,
  }) async {
    Object? lastError;
    for (var attempt = 0; attempt <= _retries; attempt++) {
      try {
        final response = await _client.get(
          Uri.parse(url),
          headers: {
            'Referer': referer,
            'User-Agent': _userAgent,
          },
        );
        if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
          return response.bodyBytes;
        }
        lastError = 'HTTP ${response.statusCode}';
      } catch (error) {
        lastError = error;
      }
      if (attempt < _retries) {
        await Future<void>.delayed(_retryDelay);
      }
    }
    throw AnyFlipDownloaderException(
      'Download failed for $url after ${_retries + 1} attempts: $lastError',
    );
  }

  Future<void> _writePdf(String pdfPath, List<Uint8List> images) async {
    final doc = pw.Document();
    for (final bytes in images) {
      final decoded = await _decodeImageSize(bytes);
      final image = pw.MemoryImage(bytes);
      final format = PdfPageFormat(
        decoded.width.toDouble(),
        decoded.height.toDouble(),
      );
      doc.addPage(
        pw.Page(
          pageFormat: format,
          margin: pw.EdgeInsets.zero,
          build: (context) => pw.Image(image, fit: pw.BoxFit.fill),
        ),
      );
    }
    final saved = await doc.save();
    await File(pdfPath).writeAsBytes(saved, flush: true);
  }

  Future<({int width, int height})> _decodeImageSize(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final image = frame.image;
    final size = (width: image.width, height: image.height);
    image.dispose();
    if (size.width <= 0 || size.height <= 0) {
      throw AnyFlipDownloaderException('Downloaded page image is invalid.');
    }
    return size;
  }

  String _titleFromUrl(Uri uri) {
    final segments =
        uri.pathSegments.where((s) => s.trim().isNotEmpty).toList();
    if (segments.isNotEmpty) return segments.last;
    return 'anyflip-download';
  }

  String _safeTitle(String raw) {
    var title = raw.trim();
    if (title.isEmpty) title = 'anyflip-download';
    title = title.replaceAll(RegExp(r'''['\\:]'''), '');
    title = title.replaceAll(RegExp(r'[<>"/|?*]'), '_');
    title = title.replaceAll(RegExp(r'\s+'), ' ').trim();
    title = title.replaceAll(RegExp(r'\.+$'), '');
    if (title.isEmpty) title = 'anyflip-download';
    if (title.length > 80) {
      title = title.substring(0, 80).trim();
    }
    return title;
  }
}
