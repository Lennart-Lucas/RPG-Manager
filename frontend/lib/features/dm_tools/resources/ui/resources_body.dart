import 'package:flutter/material.dart';

import '../../../auth/data/auth_api.dart';
import '../../../auth/state/auth_controller.dart';
import '../resources_icons.dart';
import '../data/local_file_path_store.dart';
import '../data/local_resource_file_copy.dart';
import '../data/resource_models.dart';
import '../data/resources_api.dart';
import 'author_form_sheet.dart';
import 'file_form_sheet.dart';

class ResourcesBody extends StatefulWidget {
  const ResourcesBody({super.key, required this.auth});

  final AuthController auth;

  @override
  State<ResourcesBody> createState() => _ResourcesBodyState();
}

class _ResourcesBodyState extends State<ResourcesBody> {
  final _api = ResourcesApi();
  final _pathStore = LocalFilePathStore();
  final _fileCopy = LocalResourceFileCopy();

  bool _loading = true;
  String? _error;
  List<Author> _authors = const [];
  List<ResourceFile> _files = const [];
  Map<int, String> _localPaths = {};
  bool _fabOpen = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<String?> _token() => widget.auth.requireAccessToken();

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final token = await _token();
      if (token == null) {
        throw AuthApiException('Not authenticated');
      }
      final authors = await _api.listAuthors(token);
      final files = await _api.listFiles(token);
      final paths = await _pathStore.allPaths();
      if (!mounted) return;
      setState(() {
        _authors = authors;
        _files = files;
        _localPaths = paths;
        _loading = false;
      });
    } on AuthApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load resources';
        _loading = false;
      });
    }
  }

  Future<void> _createAuthor() async {
    setState(() => _fabOpen = false);
    final created = await showAuthorFormSheet(context);
    if (created == null || !mounted) return;
    try {
      final token = await _token();
      if (token == null) return;
      await _api.createAuthor(
        accessToken: token,
        name: created.name,
        links: created.links,
      );
      await _reload();
    } on AuthApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    }
  }

  Future<void> _createFile() async {
    setState(() => _fabOpen = false);
    if (_authors.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Create an author before adding a file'),
        ),
      );
      return;
    }
    final draft = await showFileFormSheet(context, authors: _authors);
    if (draft == null || !mounted) return;

    ResourceFile? created;
    try {
      final token = await _token();
      if (token == null) return;
      created = await _api.createFile(
        accessToken: token,
        name: draft.name,
        authorId: draft.authorId,
        source: draft.source,
      );
      if (draft.pickedPath != null) {
        try {
          final dest = await _fileCopy.copyPickedFile(
            fileId: created.id,
            sourcePath: draft.pickedPath!,
          );
          await _pathStore.setPath(created.id, dest);
        } catch (_) {
          await _api.deleteFile(accessToken: token, fileId: created.id);
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not copy the file locally. Record removed.'),
            ),
          );
          await _reload();
          return;
        }
      }
      await _reload();
    } on AuthApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    }
  }

  Future<void> _deleteAuthor(Author author) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete author?'),
        content: Text('Remove ${author.name}?'),
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
    try {
      final token = await _token();
      if (token == null) return;
      await _api.deleteAuthor(accessToken: token, authorId: author.id);
      await _reload();
    } on AuthApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    }
  }

  Future<void> _deleteFile(ResourceFile file) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete file?'),
        content: Text('Remove ${file.name}?'),
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
    try {
      final token = await _token();
      if (token == null) return;
      await _api.deleteFile(accessToken: token, fileId: file.id);
      await _pathStore.removePath(file.id);
      await _reload();
    } on AuthApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    }
  }

  Future<void> _openLocal(ResourceFile file) async {
    final path = _localPaths[file.id];
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

  String _authorName(int authorId) {
    for (final author in _authors) {
      if (author.id == authorId) return author.name;
    }
    return 'Author #$authorId';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Stack(
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: Center(
              child: Opacity(
                opacity: 0.08,
                child: Icon(
                  resourcesMenuIcon,
                  size: 220,
                  color: scheme.onSurface,
                ),
              ),
            ),
          ),
        ),
        if (_loading)
          const Center(child: CircularProgressIndicator())
        else if (_error != null)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_error!, textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _reload,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          )
        else
          RefreshIndicator(
            onRefresh: _reload,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
              children: [
                Text(
                  'Authors',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                if (_authors.isEmpty)
                  Text(
                    'No authors yet.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                  )
                else
                  ..._authors.map(
                    (author) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.person_outline),
                      title: Text(author.name),
                      subtitle: author.links.isEmpty
                          ? null
                          : Text(
                              '${author.links.length} link'
                              '${author.links.length == 1 ? '' : 's'}',
                            ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _deleteAuthor(author),
                      ),
                    ),
                  ),
                const SizedBox(height: 28),
                Text(
                  'Files',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                if (_files.isEmpty)
                  Text(
                    'No files yet.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                  )
                else
                  ..._files.map(
                    (file) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.insert_drive_file_outlined),
                      title: Text(file.name),
                      subtitle: Text(
                        [
                          _authorName(file.authorId),
                          if (_localPaths.containsKey(file.id)) 'Local copy',
                          if (file.source != null && file.source!.isNotEmpty)
                            'Source URL',
                        ].join(' · '),
                      ),
                      onTap: _localPaths.containsKey(file.id)
                          ? () => _openLocal(file)
                          : null,
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _deleteFile(file),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        Positioned(
          right: 20,
          bottom: 20,
          child: _ResourcesFab(
            open: _fabOpen,
            onToggle: () => setState(() => _fabOpen = !_fabOpen),
            onAuthor: _createAuthor,
            onFile: _createFile,
          ),
        ),
      ],
    );
  }
}

class _ResourcesFab extends StatelessWidget {
  const _ResourcesFab({
    required this.open,
    required this.onToggle,
    required this.onAuthor,
    required this.onFile,
  });

  final bool open;
  final VoidCallback onToggle;
  final VoidCallback onAuthor;
  final VoidCallback onFile;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        AnimatedOpacity(
          opacity: open ? 1 : 0,
          duration: const Duration(milliseconds: 180),
          child: IgnorePointer(
            ignoring: !open,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _FabAction(
                  label: 'Author',
                  icon: Icons.person_add_alt_1_outlined,
                  onPressed: onAuthor,
                ),
                const SizedBox(height: 10),
                _FabAction(
                  label: 'File',
                  icon: Icons.note_add_outlined,
                  onPressed: onFile,
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
        FloatingActionButton(
          onPressed: onToggle,
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          child: AnimatedRotation(
            turns: open ? 0.125 : 0,
            duration: const Duration(milliseconds: 180),
            child: const Icon(Icons.add),
          ),
        ),
      ],
    );
  }
}

class _FabAction extends StatelessWidget {
  const _FabAction({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          elevation: 2,
          borderRadius: BorderRadius.circular(8),
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Text(label),
          ),
        ),
        const SizedBox(width: 10),
        FloatingActionButton.small(
          heroTag: 'resources-fab-$label',
          onPressed: onPressed,
          child: Icon(icon),
        ),
      ],
    );
  }
}
