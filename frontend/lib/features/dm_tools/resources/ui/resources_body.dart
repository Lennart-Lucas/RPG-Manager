import 'package:flutter/material.dart';

import '../../../auth/data/auth_api.dart';
import '../../../auth/state/auth_controller.dart';
import '../../../shell/app_page.dart';
import '../../../shell/shell_page_app_bar.dart';
import '../resources_icons.dart';
import '../data/local_file_path_store.dart';
import '../data/local_resource_file_copy.dart';
import '../data/resource_models.dart';
import '../data/resources_api.dart';
import 'author_detail_page.dart';
import 'author_form_sheet.dart';
import 'file_detail_page.dart';
import 'file_form_sheet.dart';

class ResourcesBody extends StatefulWidget {
  const ResourcesBody({super.key, required this.auth});

  final AuthController auth;

  @override
  State<ResourcesBody> createState() => _ResourcesBodyState();
}

class _ResourcesBodyState extends State<ResourcesBody> {
  static String get _pageKey => AppPage.resources.name;

  final _api = ResourcesApi();
  final _pathStore = LocalFilePathStore();
  final _fileCopy = LocalResourceFileCopy();

  bool _loading = true;
  String? _error;
  List<Author> _authors = const [];
  List<ResourceFile> _files = const [];
  Map<int, String> _localPaths = {};
  bool _fabOpen = false;
  int? _selectedAuthorId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _installShellAppBar();
    });
    _reload();
  }

  @override
  void dispose() {
    ShellPageAppBarStore.instance.clearPageBar(_pageKey);
    super.dispose();
  }

  void _installShellAppBar() {
    if (!mounted) return;
    if (!isDesktopFileStorageSupported) {
      ShellPageAppBarStore.instance.clearPageBar(_pageKey);
      return;
    }
    ShellPageAppBarStore.instance.setPageBar(
      _pageKey,
      ShellPageAppBarData(
        actions: [
          IconButton(
            tooltip: 'Open files folder',
            icon: const Icon(Icons.folder_open_outlined),
            onPressed: _openFilesFolder,
          ),
        ],
      ),
    );
  }

  Future<void> _openFilesFolder() async {
    try {
      await _fileCopy.openResourcesFolder();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the files folder')),
      );
    }
  }

  Future<String?> _token() => widget.auth.requireAccessToken();

  List<ResourceFile> _filesForAuthor(int authorId) {
    return _files.where((file) => file.authorId == authorId).toList();
  }

  void _selectAuthor(int authorId) {
    setState(() => _selectedAuthorId = authorId);
  }

  void _toggleAuthor(int authorId) {
    setState(() {
      if (_selectedAuthorId == authorId) {
        _selectedAuthorId = null;
      } else {
        _selectedAuthorId = authorId;
      }
    });
  }

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
        if (_selectedAuthorId != null &&
            authors.every((author) => author.id != _selectedAuthorId)) {
          _selectedAuthorId = null;
        }
        if (_selectedAuthorId == null && authors.isNotEmpty) {
          _selectedAuthorId = authors.first.id;
        }
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
      final author = await _api.createAuthor(
        accessToken: token,
        name: created.name,
        links: created.links,
      );
      await _reload();
      _selectAuthor(author.id);
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

    try {
      final token = await _token();
      if (token == null) return;
      final created = await _api.createFile(
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
      _selectAuthor(draft.authorId);
    } on AuthApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    }
  }

  Future<void> _openAuthorDetail(Author author) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => AuthorDetailPage(
          auth: widget.auth,
          author: author,
          files: _filesForAuthor(author.id),
          localPaths: _localPaths,
        ),
      ),
    );
    if (mounted) await _reload();
  }

  Future<void> _openFileDetail(ResourceFile file) async {
    Author? author;
    for (final candidate in _authors) {
      if (candidate.id == file.authorId) {
        author = candidate;
        break;
      }
    }
    if (author == null) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => FileDetailPage(
          auth: widget.auth,
          file: file,
          author: author!,
          localPath: _localPaths[file.id],
        ),
      ),
    );
    if (mounted) await _reload();
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
                  size: 440,
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
        else if (_authors.isEmpty)
          RefreshIndicator(
            onRefresh: _reload,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(24, 48, 24, 100),
              children: [
                Icon(
                  Icons.menu_book_outlined,
                  size: 64,
                  color: scheme.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  'No authors yet',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  'Add an author or file to start building your resource library.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          )
        else
          RefreshIndicator(
            onRefresh: _reload,
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              itemCount: _authors.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final author = _authors[index];
                final selected = author.id == _selectedAuthorId;
                final authorFiles = selected
                    ? _filesForAuthor(author.id)
                    : const <ResourceFile>[];

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _AuthorListTile(
                      author: author,
                      fileCount: _filesForAuthor(author.id).length,
                      selected: selected,
                      onOpen: () => _openAuthorDetail(author),
                      onToggleExpand: () => _toggleAuthor(author.id),
                    ),
                    if (selected) ...[
                      const SizedBox(height: 8),
                      if (author.links.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(
                            left: 16,
                            right: 8,
                            bottom: 8,
                          ),
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              for (final link in author.links)
                                TextButton(
                                  style: TextButton.styleFrom(
                                    visualDensity: VisualDensity.compact,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                    ),
                                    foregroundColor: scheme.onSurfaceVariant,
                                  ),
                                  onPressed: () => _openSource(link.url),
                                  child: Text(link.source),
                                ),
                            ],
                          ),
                        ),
                      if (authorFiles.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Text(
                            'No files for this author yet.',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        )
                      else
                        ...authorFiles.map(
                          (file) => Padding(
                            padding: const EdgeInsets.only(
                              left: 16,
                              bottom: 8,
                            ),
                            child: _FileListTile(
                              file: file,
                              hasLocal: _localPaths.containsKey(file.id),
                              onTap: () => _openFileDetail(file),
                            ),
                          ),
                        ),
                    ],
                  ],
                );
              },
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

class _AuthorListTile extends StatelessWidget {
  const _AuthorListTile({
    required this.author,
    required this.fileCount,
    required this.selected,
    required this.onOpen,
    required this.onToggleExpand,
  });

  final Author author;
  final int fileCount;
  final bool selected;
  final VoidCallback onOpen;
  final VoidCallback onToggleExpand;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fileLabel = fileCount == 1 ? '1 file' : '$fileCount files';
    final linkLabel = author.links.isEmpty
        ? null
        : (author.links.length == 1
            ? '1 link'
            : '${author.links.length} links');

    return Material(
      color: selected ? scheme.primaryContainer : scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 4, 10),
          child: Row(
            children: [
              Icon(
                Icons.person_outline,
                color: selected ? scheme.onPrimaryContainer : scheme.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      author.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: selected ? scheme.onPrimaryContainer : null,
                          ),
                    ),
                    Text(
                      [fileLabel, ?linkLabel].join(' · '),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: selected
                                ? scheme.onPrimaryContainer
                                    .withValues(alpha: 0.8)
                                : scheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: selected ? 'Hide files' : 'Show files',
                onPressed: onToggleExpand,
                style: IconButton.styleFrom(
                  foregroundColor: selected
                      ? scheme.onPrimaryContainer
                      : scheme.onSurfaceVariant,
                  minimumSize: const Size(48, 48),
                  tapTargetSize: MaterialTapTargetSize.padded,
                ),
                icon: Icon(
                  selected ? Icons.expand_less : Icons.expand_more,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FileListTile extends StatelessWidget {
  const _FileListTile({
    required this.file,
    required this.hasLocal,
    required this.onTap,
  });

  final ResourceFile file;
  final bool hasLocal;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final source = file.source?.trim();
    final hasSource = source != null && source.isNotEmpty;
    final subtitle = hasSource
        ? source
        : hasLocal
            ? 'Local copy'
            : 'Metadata only';

    return Material(
      color: scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
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
              Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
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
