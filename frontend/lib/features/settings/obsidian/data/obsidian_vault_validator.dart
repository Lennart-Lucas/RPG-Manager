import 'dart:io';

/// Managed export root inside an Obsidian vault.
const obsidianManagedFolderName = 'RPG Manager';

/// True when [path] is an existing directory containing a `.obsidian` folder.
bool isValidObsidianVault(String path) {
  final trimmed = path.trim();
  if (trimmed.isEmpty) return false;
  final root = Directory(trimmed);
  if (!root.existsSync()) return false;
  final marker = Directory.fromUri(
    root.uri.resolve('.obsidian/'),
  );
  return marker.existsSync();
}

/// Human-readable validation failure, or null if [path] is a valid vault.
String? obsidianVaultValidationError(String path) {
  final trimmed = path.trim();
  if (trimmed.isEmpty) return 'Choose an Obsidian vault folder';
  final root = Directory(trimmed);
  if (!root.existsSync()) {
    return 'Folder does not exist';
  }
  final marker = Directory.fromUri(root.uri.resolve('.obsidian/'));
  if (!marker.existsSync()) {
    return 'Not an Obsidian vault (missing .obsidian folder)';
  }
  return null;
}
