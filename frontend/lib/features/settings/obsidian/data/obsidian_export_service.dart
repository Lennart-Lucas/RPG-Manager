import 'dart:io';

import 'package:path/path.dart' as p;

import '../../../catalog/data/catalog_api.dart';
import '../../../catalog/data/catalog_kind.dart';
import '../../../catalog/data/catalog_models.dart';
import 'obsidian_note_mapper.dart';
import 'obsidian_vault_validator.dart';

class ObsidianExportResult {
  const ObsidianExportResult({
    required this.notesWritten,
    required this.filesDeleted,
  });

  final int notesWritten;
  final int filesDeleted;
}

/// Full mirror of catalog → `{vault}/RPG Manager/`.
class ObsidianExportService {
  ObsidianExportService({
    CatalogApi? api,
    ObsidianNoteMapper? mapper,
  })  : _api = api ?? CatalogApi(),
        _mapper = mapper ?? ObsidianNoteMapper();

  final CatalogApi _api;
  final ObsidianNoteMapper _mapper;

  Future<ObsidianExportResult> exportAll({
    required String accessToken,
    required String vaultPath,
  }) async {
    final error = obsidianVaultValidationError(vaultPath);
    if (error != null) {
      throw StateError(error);
    }

    final itemsByKind = <CatalogKind, List<CatalogItem>>{};
    for (final kind in ObsidianNoteMapper.exportKinds) {
      itemsByKind[kind] = await _api.list(accessToken, kind);
    }

    final notes = _mapper.planAll(itemsByKind);
    final managedRoot = Directory(
      p.join(vaultPath, obsidianManagedFolderName),
    );
    if (!managedRoot.existsSync()) {
      await managedRoot.create(recursive: true);
    }

    final expected = <String>{};
    for (final note in notes) {
      final absolute = p.normalize(
        p.joinAll([vaultPath, ...note.relativePath.split('/')]),
      );
      expected.add(p.normalize(absolute));
      final file = File(absolute);
      await file.parent.create(recursive: true);
      await file.writeAsString(note.contents, flush: true);
    }

    final deleted = await _pruneOrphans(managedRoot, expected);
    return ObsidianExportResult(
      notesWritten: notes.length,
      filesDeleted: deleted,
    );
  }

  /// Deletes `.md` files under [managedRoot] that are not in [expectedAbsolute].
  Future<int> _pruneOrphans(
    Directory managedRoot,
    Set<String> expectedAbsolute,
  ) async {
    if (!managedRoot.existsSync()) return 0;
    var deleted = 0;
    final files = managedRoot
        .listSync(recursive: true, followLinks: false)
        .whereType<File>()
        .where((f) => p.extension(f.path).toLowerCase() == '.md')
        .toList();

    for (final file in files) {
      final normalized = p.normalize(file.path);
      if (expectedAbsolute.contains(normalized)) continue;
      // Also compare with forward-slash normalized forms on Windows.
      final alt = normalized.replaceAll('/', '\\');
      final alt2 = normalized.replaceAll('\\', '/');
      final match = expectedAbsolute.any(
        (e) =>
            e == normalized ||
            e.replaceAll('/', '\\') == alt ||
            e.replaceAll('\\', '/') == alt2 ||
            p.equals(e, normalized),
      );
      if (match) continue;
      await file.delete();
      deleted++;
    }

    await _removeEmptyDirectories(managedRoot);
    return deleted;
  }

  Future<void> _removeEmptyDirectories(Directory root) async {
    if (!root.existsSync()) return;
    final dirs = root
        .listSync(recursive: true, followLinks: false)
        .whereType<Directory>()
        .toList()
      ..sort((a, b) => b.path.length.compareTo(a.path.length));
    for (final dir in dirs) {
      if (!dir.existsSync()) continue;
      if (dir.listSync(followLinks: false).isEmpty) {
        await dir.delete();
      }
    }
  }
}
