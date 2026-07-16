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
    switch (defaultTargetPlatform) {
      case TargetPlatform.windows:
        await Process.start('cmd', ['/c', 'start', '', absolutePath]);
      case TargetPlatform.macOS:
        await Process.start('open', [absolutePath]);
      case TargetPlatform.linux:
        await Process.start('xdg-open', [absolutePath]);
      default:
        throw UnsupportedError('Opening local files is desktop-only');
    }
  }
}
