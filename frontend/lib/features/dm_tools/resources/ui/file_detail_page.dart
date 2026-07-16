import 'package:flutter/material.dart';

import '../../../auth/data/auth_api.dart';
import '../../../auth/state/auth_controller.dart';
import '../data/local_file_path_store.dart';
import '../data/local_resource_file_copy.dart';
import '../data/resource_models.dart';
import '../data/resources_api.dart';
import 'file_form_sheet.dart';
import 'local_file_preview.dart';

class FileDetailPage extends StatefulWidget {
  const FileDetailPage({
    super.key,
    required this.auth,
    required this.file,
    required this.author,
    this.localPath,
  });

  final AuthController auth;
  final ResourceFile file;
  final Author author;
  final String? localPath;

  @override
  State<FileDetailPage> createState() => _FileDetailPageState();
}

class _FileDetailPageState extends State<FileDetailPage> {
  final _api = ResourcesApi();
  final _pathStore = LocalFilePathStore();
  final _fileCopy = LocalResourceFileCopy();

  late ResourceFile _file = widget.file;
  late Author _author = widget.author;
  late String? _localPath = widget.localPath;
  bool _deleting = false;
  bool _saving = false;

  Future<String?> _token() => widget.auth.requireAccessToken();

  Future<void> _editFile() async {
    try {
      final token = await _token();
      if (token == null) return;
      final authors = await _api.listAuthors(token);
      if (!mounted) return;
      if (authors.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No authors available')),
        );
        return;
      }

      final draft = await showFileFormSheet(
        context,
        authors: authors,
        initial: _file,
        existingLocalPath: _localPath,
      );
      if (draft == null || !mounted) return;

      setState(() => _saving = true);
      final updatedToken = await _token();
      if (updatedToken == null) {
        if (mounted) setState(() => _saving = false);
        return;
      }
      final updated = await _api.updateFile(
        accessToken: updatedToken,
        fileId: _file.id,
        name: draft.name,
        authorId: draft.authorId,
        source: draft.source,
      );

      var localPath = _localPath;
      if (draft.pickedPath != null) {
        try {
          localPath = await _fileCopy.copyPickedFile(
            fileId: updated.id,
            sourcePath: draft.pickedPath!,
          );
          await _pathStore.setPath(updated.id, localPath);
        } catch (_) {
          if (!mounted) return;
          setState(() => _saving = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not replace the local file')),
          );
          return;
        }
      }

      Author author = _author;
      for (final candidate in authors) {
        if (candidate.id == updated.authorId) {
          author = candidate;
          break;
        }
      }

      if (!mounted) return;
      setState(() {
        _file = updated;
        _author = author;
        _localPath = localPath;
        _saving = false;
      });
    } on AuthApiException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    }
  }

  Future<void> _openSource() async {
    final source = _file.source?.trim();
    if (source == null || source.isEmpty) return;
    try {
      await _fileCopy.openUrl(source);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open link')),
      );
    }
  }

  Future<void> _openLocal() async {
    final path = _localPath;
    if (path == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No local copy on this device')),
      );
      return;
    }
    try {
      await _fileCopy.openLocalPath(path);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open local file')),
      );
    }
  }

  Future<void> _deleteFile() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete file?'),
        content: Text('Remove ${_file.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _deleting = true);
    try {
      final token = await _token();
      if (token == null) return;
      await _api.deleteFile(accessToken: token, fileId: _file.id);
      await _pathStore.removePath(_file.id);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on AuthApiException catch (e) {
      if (!mounted) return;
      setState(() => _deleting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final source = _file.source?.trim();
    final hasSource = source != null && source.isNotEmpty;
    final hasLocal = _localPath != null && _localPath!.isNotEmpty;
    final busy = _deleting || _saving;

    return Scaffold(
      appBar: AppBar(
        title: Text(_file.name),
        actions: [
          IconButton(
            tooltip: 'Edit file',
            onPressed: busy ? null : _editFile,
            icon: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.edit_outlined),
          ),
          IconButton(
            tooltip: 'Delete file',
            onPressed: busy ? null : _deleteFile,
            icon: _deleting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: Center(
                child: Opacity(
                  opacity: 0.08,
                  child: Icon(
                    Icons.insert_drive_file_outlined,
                    size: 440,
                    color: scheme.onSurface,
                  ),
                ),
              ),
            ),
          ),
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (hasLocal) LocalFilePreview(path: _localPath!),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.person_outline),
                title: const Text('Author'),
                subtitle: Text(_author.name),
              ),
              if (hasSource)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.link),
                  title: const Text('Source'),
                  subtitle: Text(source),
                  onTap: _openSource,
                  trailing: Icon(
                    Icons.open_in_new,
                    color: scheme.onSurfaceVariant,
                  ),
                )
              else
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.link_off),
                  title: const Text('Source'),
                  subtitle: Text(
                    'No source URL',
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  hasLocal ? Icons.folder_open : Icons.folder_off_outlined,
                ),
                title: const Text('Local copy'),
                subtitle: Text(
                  hasLocal ? _localPath! : 'Not stored on this device',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: hasLocal ? _openLocal : null,
                trailing: hasLocal
                    ? Icon(Icons.open_in_new, color: scheme.onSurfaceVariant)
                    : null,
              ),
              if (hasLocal || hasSource) ...[
                const SizedBox(height: 16),
                if (hasLocal)
                  FilledButton.icon(
                    onPressed: _openLocal,
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('Open local file'),
                  ),
                if (hasLocal && hasSource) const SizedBox(height: 8),
                if (hasSource)
                  OutlinedButton.icon(
                    onPressed: _openSource,
                    icon: const Icon(Icons.link),
                    label: const Text('Open source URL'),
                  ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
