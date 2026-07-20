import 'package:flutter/material.dart';

import '../../../auth/data/auth_api.dart';
import '../../../auth/state/auth_controller.dart';
import '../../../catalog/data/catalog_api.dart';
import '../../../catalog/data/catalog_kind.dart';
import '../../../catalog/data/catalog_models.dart';
import '../../../player_options/classes/data/class_model.dart';
import '../../../player_options/spells/data/spell_list_derived_data.dart';
import '../../../player_options/spells/data/spell_model.dart';
import '../../../player_options/spells/ui/spell_detail_page.dart';
import '../../../player_options/spells/ui/spell_list_item_card.dart';
import '../../pdf_extract/ui/start_spell_extraction.dart';
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
  final _catalogApi = CatalogApi();
  final _pathStore = LocalFilePathStore();
  final _fileCopy = LocalResourceFileCopy();

  late ResourceFile _file = widget.file;
  late Author _author = widget.author;
  late String? _localPath = widget.localPath;
  bool _deleting = false;
  bool _saving = false;
  bool _togglingProcessed = false;

  bool _spellsLoading = true;
  String? _spellsError;
  List<SpellCatalogEntry> _linkedSpells = const [];
  Map<String, List<String>> _classNamesBySpellKey = const {};
  Map<String, List<({String id, String name})>> _tagEntriesBySpellKey =
      const {};

  @override
  void initState() {
    super.initState();
    _loadLinkedSpells();
  }

  Future<String?> _token() => widget.auth.requireAccessToken();

  Spell? _spellFromItem(CatalogItem item) {
    final payload = item.payload;
    if (payload == null) return null;
    try {
      return Spell.fromJson(payload);
    } catch (_) {
      return null;
    }
  }

  Future<void> _loadLinkedSpells() async {
    setState(() {
      _spellsLoading = true;
      _spellsError = null;
    });
    try {
      final token = await _token();
      if (token == null) {
        throw AuthApiException('Not authenticated');
      }
      final results = await Future.wait([
        _catalogApi.list(token, CatalogKind.spells),
        _catalogApi.list(token, CatalogKind.classes),
        _catalogApi.list(token, CatalogKind.spellTags),
      ]);
      final spellItems = results[0];
      final classItems = results[1];
      final spellTags = results[2];
      final casters = classItems.where((item) {
        return ClassRecord.fromCatalogPayload(
          name: item.name,
          payload: item.payload,
        ).isCaster;
      }).toList();

      final linked = <SpellCatalogEntry>[];
      for (final item in spellItems) {
        final spell = _spellFromItem(item);
        if (spell == null) continue;
        if (spell.sourceFileId != _file.id) continue;
        linked.add(
          SpellCatalogEntry(
            item: item,
            spell: spell.copyWith(name: item.name),
          ),
        );
      }
      linked.sort(
        (a, b) =>
            a.spell.name.toLowerCase().compareTo(b.spell.name.toLowerCase()),
      );

      final classNamesById = {
        for (final c in casters)
          '${c.id}': c.name.trim().isEmpty ? '${c.id}' : c.name,
      };
      final tagNamesById = {
        for (final t in spellTags)
          '${t.id}': t.name.trim().isEmpty ? '${t.id}' : t.name,
      };

      final classNamesBySpellKey = <String, List<String>>{};
      final tagEntriesBySpellKey =
          <String, List<({String id, String name})>>{};
      for (final entry in linked) {
        final classNames = entry.spell.classIds
            .map((id) => classNamesById['$id'])
            .whereType<String>()
            .toList(growable: false)
          ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
        classNamesBySpellKey[entry.key] = classNames;

        final tagEntries = <({String id, String name})>[];
        for (final id in entry.spell.tagIds) {
          final name = tagNamesById['$id'];
          if (name != null) {
            tagEntries.add((id: '$id', name: name));
          }
        }
        tagEntries.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
        tagEntriesBySpellKey[entry.key] = tagEntries;
      }

      if (!mounted) return;
      setState(() {
        _linkedSpells = linked;
        _classNamesBySpellKey = classNamesBySpellKey;
        _tagEntriesBySpellKey = tagEntriesBySpellKey;
        _spellsLoading = false;
        _spellsError = null;
      });
    } on AuthApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _spellsLoading = false;
        _spellsError = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _spellsLoading = false;
        _spellsError = 'Could not load imported spells';
      });
    }
  }

  Future<void> _setProcessed(bool value) async {
    if (_togglingProcessed || _deleting || _saving) return;
    setState(() => _togglingProcessed = true);
    try {
      final token = await _token();
      if (token == null) {
        if (mounted) setState(() => _togglingProcessed = false);
        return;
      }
      final updated = await _api.setFileProcessed(
        accessToken: token,
        fileId: _file.id,
        processed: value,
      );
      if (!mounted) return;
      setState(() {
        _file = updated;
        _togglingProcessed = false;
      });
    } on AuthApiException catch (e) {
      if (!mounted) return;
      setState(() => _togglingProcessed = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    }
  }

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

  Future<void> _extractSpells() async {
    final path = _localPath;
    if (path == null || path.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No local PDF on this device')),
      );
      return;
    }
    await startSpellExtraction(
      context: context,
      auth: widget.auth,
      file: _file,
      localPath: path,
    );
    if (mounted) await _loadLinkedSpells();
  }

  Future<void> _openSpell(SpellCatalogEntry entry) async {
    final classNames = _classNamesBySpellKey[entry.key] ?? const [];
    final tagEntries = _tagEntriesBySpellKey[entry.key] ?? const [];
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => SpellDetailPage(
          auth: widget.auth,
          item: entry.item,
          spell: entry.spell,
          classNames: classNames,
          tagNames: tagEntries.map((e) => e.name).toList(),
          sourceFileName: _file.name,
        ),
      ),
    );
    if (!mounted) return;
    await _loadLinkedSpells();
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
    final textTheme = Theme.of(context).textTheme;
    final source = _file.source?.trim();
    final hasSource = source != null && source.isNotEmpty;
    final hasLocal = _localPath != null && _localPath!.isNotEmpty;
    final busy = _deleting || _saving || _togglingProcessed;
    final aiEnabled = widget.auth.user?.aiIntegration ?? false;
    final canExtract = hasLocal && aiEnabled && !busy;
    final importedCount = _linkedSpells.length;

    return Scaffold(
      appBar: AppBar(
        title: Text(_file.name),
        actions: [
          if (hasLocal)
            IconButton(
              tooltip: aiEnabled
                  ? 'Extract spells'
                  : 'Enable AI integration to extract spells',
              onPressed: canExtract ? _extractSpells : null,
              icon: const Icon(Icons.auto_fix_high_outlined),
            ),
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
                  opacity: 0.04,
                  child: Icon(
                    Icons.insert_drive_file_outlined,
                    size: 440,
                    color: scheme.onSurface,
                  ),
                ),
              ),
            ),
          ),
          CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    if (hasLocal) ...[
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: scheme.outlineVariant),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: LocalFilePreview(path: _localPath!),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: scheme.outlineVariant),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
                        child: Column(
                          children: [
                            SwitchListTile(
                              secondary: Icon(
                                _file.processed
                                    ? Icons.check_circle
                                    : Icons.radio_button_unchecked,
                                color: _file.processed
                                    ? scheme.primary
                                    : scheme.onSurfaceVariant,
                              ),
                              title: const Text('Processed'),
                              subtitle: Text(
                                _file.processed
                                    ? 'Marked as done'
                                    : 'Not done yet',
                              ),
                              value: _file.processed,
                              onChanged: busy ? null : _setProcessed,
                            ),
                            ListTile(
                              leading: Icon(
                                Icons.person_outline,
                                color: scheme.primary,
                              ),
                              title: const Text('Author'),
                              subtitle: Text(_author.name),
                            ),
                            if (hasSource)
                              ListTile(
                                leading: Icon(
                                  Icons.link,
                                  color: scheme.primary,
                                ),
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
                                leading: Icon(
                                  Icons.link_off,
                                  color: scheme.onSurfaceVariant,
                                ),
                                title: const Text('Source'),
                                subtitle: Text(
                                  'No source URL',
                                  style: TextStyle(
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ListTile(
                              leading: Icon(
                                hasLocal
                                    ? Icons.folder_open
                                    : Icons.folder_off_outlined,
                                color: hasLocal
                                    ? scheme.primary
                                    : scheme.onSurfaceVariant,
                              ),
                              title: const Text('Local copy'),
                              subtitle: Text(
                                hasLocal
                                    ? _localPath!
                                    : 'Not stored on this device',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              onTap: hasLocal ? _openLocal : null,
                              trailing: hasLocal
                                  ? Icon(
                                      Icons.open_in_new,
                                      color: scheme.onSurfaceVariant,
                                    )
                                  : null,
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (hasLocal || hasSource) ...[
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (hasLocal)
                            FilledButton.icon(
                              onPressed: canExtract ? _extractSpells : null,
                              icon: const Icon(Icons.auto_fix_high_outlined),
                              label: const Text('Extract spells'),
                            ),
                          if (hasLocal)
                            FilledButton.tonalIcon(
                              onPressed: _openLocal,
                              icon: const Icon(Icons.open_in_new),
                              label: const Text('Open local file'),
                            ),
                          if (hasSource)
                            OutlinedButton.icon(
                              onPressed: _openSource,
                              icon: const Icon(Icons.link),
                              label: const Text('Open source URL'),
                            ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 28),
                    Row(
                      children: [
                        Text(
                          'Imported',
                          style: textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (!_spellsLoading && _spellsError == null)
                          Text(
                            '$importedCount',
                            style: textTheme.titleMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Catalog records linked to this file',
                      style: textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Spells',
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ]),
                ),
              ),
              if (_spellsLoading)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                )
              else if (_spellsError != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                    child: Column(
                      children: [
                        Text(
                          _spellsError!,
                          textAlign: TextAlign.center,
                          style: textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 12),
                        TextButton.icon(
                          onPressed: _loadLinkedSpells,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              else if (_linkedSpells.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 48),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: scheme.outlineVariant),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Text(
                          'No spells linked to this file yet.',
                          textAlign: TextAlign.center,
                          style: textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 48),
                  sliver: SliverLayoutBuilder(
                    builder: (context, constraints) {
                      const itemSpacing = 10.0;
                      const minItemWidth = 280.0;
                      const maxItemWidth = 1060.0;
                      final availableWidth = constraints.crossAxisExtent;
                      final desiredColumns =
                          ((availableWidth + itemSpacing) /
                                  (minItemWidth + itemSpacing))
                              .floor()
                              .clamp(1, 3);
                      final listEntries = [
                        for (final entry in _linkedSpells)
                          SpellListEntry.spell(entry),
                      ];
                      final rowEntries =
                          buildSpellRowEntries(listEntries, desiredColumns);

                      return SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final rowEntry = rowEntries[index];
                            return Padding(
                              padding: EdgeInsets.only(
                                bottom:
                                    index == rowEntries.length - 1 ? 0 : 10,
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  for (var i = 0;
                                      i < rowEntry.entries.length;
                                      i++) ...[
                                    if (i > 0)
                                      const SizedBox(width: itemSpacing),
                                    Expanded(
                                      child: SpellListItemCard(
                                        spell: rowEntry.entries[i].spell,
                                        classNames: _classNamesBySpellKey[
                                                rowEntry.entries[i].key] ??
                                            const <String>[],
                                        tagEntries: _tagEntriesBySpellKey[
                                                rowEntry.entries[i].key] ??
                                            const <({String id, String name})>[],
                                        minWidth: minItemWidth,
                                        maxWidth: maxItemWidth,
                                        onTap: () =>
                                            _openSpell(rowEntry.entries[i]),
                                      ),
                                    ),
                                  ],
                                  for (var i = rowEntry.entries.length;
                                      i < desiredColumns;
                                      i++) ...[
                                    const SizedBox(width: itemSpacing),
                                    const Expanded(child: SizedBox.shrink()),
                                  ],
                                ],
                              ),
                            );
                          },
                          childCount: rowEntries.length,
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
