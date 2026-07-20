import 'package:flutter/material.dart';

import '../../../auth/data/auth_api.dart';
import '../../../auth/state/auth_controller.dart';
import '../data/local_file_path_store.dart';
import '../data/local_resource_file_copy.dart';
import '../data/resource_models.dart';
import '../data/resources_api.dart';
import 'author_form_sheet.dart';
import 'file_detail_page.dart';

class AuthorDetailPage extends StatefulWidget {
  const AuthorDetailPage({
    super.key,
    required this.auth,
    required this.author,
    required this.files,
    required this.localPaths,
  });

  final AuthController auth;
  final Author author;
  final List<ResourceFile> files;
  final Map<int, String> localPaths;

  @override
  State<AuthorDetailPage> createState() => _AuthorDetailPageState();
}

class _AuthorDetailPageState extends State<AuthorDetailPage> {
  final _api = ResourcesApi();
  final _pathStore = LocalFilePathStore();
  final _fileCopy = LocalResourceFileCopy();

  late Author _author = widget.author;
  late List<ResourceFile> _files = List.of(widget.files);
  late Map<int, String> _localPaths = Map.of(widget.localPaths);
  bool _deleting = false;
  bool _saving = false;

  Future<String?> _token() => widget.auth.requireAccessToken();

  Future<void> _editAuthor() async {
    final draft = await showAuthorFormSheet(context, initial: _author);
    if (draft == null || !mounted) return;
    setState(() => _saving = true);
    try {
      final token = await _token();
      if (token == null) {
        if (mounted) setState(() => _saving = false);
        return;
      }
      final updated = await _api.updateAuthor(
        accessToken: token,
        authorId: _author.id,
        name: draft.name,
        links: draft.links,
      );
      if (!mounted) return;
      setState(() {
        _author = updated;
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

  Future<void> _openSource(String url) async {
    try {
      await _fileCopy.openUrl(url);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open link')),
      );
    }
  }

  Future<void> _openFileDetail(ResourceFile file) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => FileDetailPage(
          auth: widget.auth,
          file: file,
          author: _author,
          localPath: _localPaths[file.id],
        ),
      ),
    );
    if (!mounted) return;
    await _refreshFiles();
  }

  Future<void> _refreshFiles() async {
    try {
      final token = await _token();
      if (token == null) return;
      final files = await _api.listFiles(token);
      final paths = await _pathStore.allPaths();
      if (!mounted) return;
      setState(() {
        _files = files.where((f) => f.authorId == _author.id).toList();
        _localPaths = paths;
      });
    } catch (_) {
      // keep current view
    }
  }

  Future<void> _deleteAuthor() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete author?'),
        content: Text('Remove ${_author.name}?'),
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
      await _api.deleteAuthor(accessToken: token, authorId: _author.id);
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
    final busy = _deleting || _saving;

    return Scaffold(
      appBar: AppBar(
        title: Text(_author.name),
        actions: [
          IconButton(
            tooltip: 'Edit author',
            onPressed: busy ? null : _editAuthor,
            icon: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.edit_outlined),
          ),
          IconButton(
            tooltip: 'Delete author',
            onPressed: busy ? null : _deleteAuthor,
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
                    Icons.person_outline,
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
              if (_author.links.isNotEmpty) ...[
                Text('Links', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                ..._author.links.map(
                  (link) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.link),
                    title: Text(link.source),
                    subtitle: Text(link.url),
                    onTap: () => _openSource(link.url),
                  ),
                ),
                const SizedBox(height: 24),
              ],
              Text('Files', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              if (_files.isEmpty)
                Text(
                  'No files linked to this author yet.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                )
              else
                ..._files.map((file) {
                  final hasLocal = _localPaths.containsKey(file.id);
                  final source = file.source?.trim();
                  final subtitle = (source != null && source.isNotEmpty)
                      ? source
                      : hasLocal
                          ? 'Local copy'
                          : 'Metadata only';
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Material(
                      color: scheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(10),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () => _openFileDetail(file),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.insert_drive_file_outlined,
                                color: scheme.primary,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      file.name,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall,
                                    ),
                                    Text(
                                      subtitle,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: scheme.onSurfaceVariant,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              if (file.processed) ...[
                                Icon(
                                  Icons.check_circle,
                                  color: scheme.primary,
                                  size: 20,
                                ),
                                const SizedBox(width: 4),
                              ],
                              Icon(
                                Icons.chevron_right,
                                color: scheme.onSurfaceVariant,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }),
            ],
          ),
        ],
      ),
    );
  }
}
