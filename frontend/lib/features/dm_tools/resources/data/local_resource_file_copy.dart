import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../../core/platform/client_platform.dart';

bool get isDesktopFileStorageSupported {
  if (kIsWeb) {
    return false;
  }
  return detectClientPlatform() == ClientPlatform.desktop;
}

class LocalResourceFileCopy {
  /// Copies [sourcePath] into app documents under resources/files/{fileId}/.
  /// Returns the destination absolute path.
  Future<String> copyPickedFile({
    required int fileId,
    required String sourcePath,
  }) async {
    final docs = await getApplicationDocumentsDirectory();
    final destDir = Directory(
      p.join(docs.path, 'resources', 'files', '$fileId'),
    );
    if (!await destDir.exists()) {
      await destDir.create(recursive: true);
    }
    final basename = p.basename(sourcePath);
    final destPath = p.join(destDir.path, basename);
    await File(sourcePath).copy(destPath);
    return destPath;
  }

  Future<void> openLocalPath(String absolutePath) async {
    if (kIsWeb) {
      return;
    }
    final file = File(absolutePath);
    if (!await file.exists()) {
      throw StateError('Local file not found');
    }
    await _openExternally(absolutePath);
  }

  /// Opens a URL or file path with the OS default handler (desktop).
  Future<void> openUrl(String url) async {
    if (kIsWeb) {
      throw UnsupportedError('Opening URLs is desktop-only for now');
    }
    final uri = Uri.tryParse(url.trim());
    if (uri == null ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.host.isEmpty) {
      throw ArgumentError('Invalid URL');
    }
    await _openExternally(uri.toString());
  }

  Future<void> _openExternally(String target) async {
    switch (defaultTargetPlatform) {
      case TargetPlatform.windows:
        await Process.start('cmd', ['/c', 'start', '', target]);
      case TargetPlatform.macOS:
        await Process.start('open', [target]);
      case TargetPlatform.linux:
        await Process.start('xdg-open', [target]);
      default:
        throw UnsupportedError('Opening links is desktop-only');
    }
  }
}
