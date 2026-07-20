import 'package:flutter/material.dart';

import '../../../auth/data/auth_api.dart';
import '../../../auth/state/auth_controller.dart';
import '../../../catalog/data/catalog_api.dart';
import '../../../catalog/data/catalog_kind.dart';
import '../../../catalog/data/catalog_models.dart';
import '../../../dm_tools/resources/data/resource_models.dart';
import '../../../dm_tools/resources/data/resources_api.dart';
import '../../../player_options/spells/data/spell_model.dart';
import '../../../player_options/spells/ui/spell_form_sheet.dart';
import '../data/extract_models.dart';
import '../data/spell_from_draft.dart';

class SpellExtractReviewPage extends StatefulWidget {
  const SpellExtractReviewPage({
    super.key,
    required this.auth,
    required this.sourceFile,
    required this.drafts,
    required this.sectionSummaries,
  });

  final AuthController auth;
  final ResourceFile sourceFile;
  final List<ExtractDraft> drafts;
  final List<ExtractSectionSummary> sectionSummaries;

  @override
  State<SpellExtractReviewPage> createState() => _SpellExtractReviewPageState();
}

class _SpellExtractReviewPageState extends State<SpellExtractReviewPage> {
  final _catalogApi = CatalogApi();
  final _resourcesApi = ResourcesApi();

  late List<ExtractDraft> _drafts;
  late List<ExtractDraft> _sorted;
  int _index = 0;
  bool _busy = false;
  List<CatalogItem> _casters = const [];
  List<CatalogItem> _spellTags = const [];
  List<ResourceFile> _files = const [];
  List<CatalogItem> _existingSpells = const [];
  String? _loadError;

  ExtractDraft? get _current {
    if (_sorted.isEmpty || _index < 0 || _index >= _sorted.length) return null;
    return _sorted[_index];
  }

  List<ExtractDraft> get _pending =>
      _drafts.where((d) => !d.rejected).toList(growable: false);

  @override
  void initState() {
    super.initState();
    _drafts = List<ExtractDraft>.from(widget.drafts);
    _resort();
    _loadCatalog();
  }

  void _resort() {
    _sorted = List<ExtractDraft>.from(_drafts)
      ..sort((a, b) {
        if (a.rejected != b.rejected) return a.rejected ? 1 : -1;
        final risk = b.riskScore.compareTo(a.riskScore);
        if (risk != 0) return risk;
        return a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase());
      });
    if (_index >= _sorted.length) {
      _index = _sorted.isEmpty ? 0 : _sorted.length - 1;
    }
  }

  Future<String?> _token() => widget.auth.requireAccessToken();

  Future<void> _loadCatalog() async {
    try {
      final token = await _token();
      if (token == null) return;
      final casters = await _catalogApi.list(token, CatalogKind.classes);
      final tags = await _catalogApi.list(token, CatalogKind.spellTags);
      final spells = await _catalogApi.list(token, CatalogKind.spells);
      final files = await _resourcesApi.listFiles(token);
      if (!mounted) return;
      setState(() {
        _casters = casters;
        _spellTags = tags;
        _existingSpells = spells;
        _files = files;
        _loadError = null;
      });
    } on AuthApiException catch (e) {
      if (!mounted) return;
      setState(() => _loadError = e.message);
    }
  }

  CatalogItem? _findLibrarySpell(String name) {
    final key = name.trim().toLowerCase();
    for (final item in _existingSpells) {
      if (item.name.trim().toLowerCase() == key) return item;
    }
    return null;
  }

  Future<void> _editCurrent() async {
    final draft = _current;
    if (draft == null || draft.rejected) return;
    final spell = spellFromExtractDraft(
      draft: draft,
      casterClasses: _casters,
      spellTags: _spellTags,
      sourceFileId: widget.sourceFile.id,
    );
    final edited = await showSpellFormSheet(
      context,
      initial: spell,
      casterClasses: _casters,
      spellTags: _spellTags,
      resourceFiles: _files,
      aiIntegrationEnabled: true,
    );
    if (edited == null || !mounted) return;
    setState(() {
      draft.payload = edited.toJson();
      draft.notes = null;
      _resort();
    });
  }

  Future<void> _rejectCurrent() async {
    final draft = _current;
    if (draft == null) return;
    setState(() {
      draft.rejected = true;
      _resort();
      _advanceAfterAction();
    });
  }

  void _advanceAfterAction() {
    final nextPending = _sorted.indexWhere((d) => !d.rejected);
    if (nextPending >= 0) {
      _index = nextPending;
    }
  }

  Future<void> _approveCurrent() async {
    final draft = _current;
    if (draft == null || draft.rejected || _busy) return;

    var spell = spellFromExtractDraft(
      draft: draft,
      casterClasses: _casters,
      spellTags: _spellTags,
      sourceFileId: widget.sourceFile.id,
    );

    final existing = _findLibrarySpell(spell.name);
    if (existing != null || draft.duplicateNameInLibrary) {
      final match = existing ??
          (draft.libraryMatchId != null
              ? CatalogItem(
                  id: draft.libraryMatchId!,
                  userId: 0,
                  kind: CatalogKind.spells,
                  name: draft.libraryMatchName ?? spell.name,
                )
              : null);
      final action = await showDialog<_DupAction>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Name already in library'),
          content: Text(
            '"${spell.name}" already exists'
            '${match != null ? ' (id ${match.id})' : ''}. '
            'Choose how to proceed.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, _DupAction.discard),
              child: const Text('Discard'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, _DupAction.rename),
              child: const Text('Rename…'),
            ),
            FilledButton(
              onPressed: match == null
                  ? null
                  : () => Navigator.pop(context, _DupAction.overwrite),
              child: const Text('Overwrite'),
            ),
          ],
        ),
      );
      if (action == null || !mounted) return;
      if (action == _DupAction.discard) {
        setState(() {
          draft.rejected = true;
          _resort();
          _advanceAfterAction();
        });
        return;
      }
      if (action == _DupAction.rename) {
        final renamed = await _promptRename(spell.name);
        if (renamed == null || !mounted) return;
        spell = spell.copyWith(name: renamed, id: Spell.slugify(renamed));
      }
      if (action == _DupAction.overwrite && match != null) {
        await _commit(
          spell: spell,
          updateId: match.id,
          draft: draft,
        );
        return;
      }
    }

    // Batch near-duplicates: warn but still allow approve
    if (draft.duplicateNameInBatch) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Duplicate in this batch'),
          content: Text(
            'Another draft in this import also uses "${spell.name}". '
            'Approve this copy anyway?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Approve'),
            ),
          ],
        ),
      );
      if (proceed != true || !mounted) return;
    }

    await _commit(spell: spell, draft: draft);
  }

  Future<String?> _promptRename(String current) async {
    final controller = TextEditingController(text: '$current (import)');
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename spell'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    final name = controller.text.trim();
    controller.dispose();
    if (ok != true || name.isEmpty) return null;
    return name;
  }

  Future<void> _commit({
    required Spell spell,
    required ExtractDraft draft,
    int? updateId,
  }) async {
    setState(() => _busy = true);
    try {
      final token = await _token();
      if (token == null) return;
      if (updateId != null) {
        await _catalogApi.update(
          accessToken: token,
          kind: CatalogKind.spells,
          itemId: updateId,
          name: spell.name,
          payload: spell.toJson(),
        );
      } else {
        await _catalogApi.create(
          accessToken: token,
          kind: CatalogKind.spells,
          name: spell.name,
          payload: spell.toJson(),
        );
      }
      if (!mounted) return;
      setState(() {
        _drafts.remove(draft);
        _busy = false;
        _resort();
        _advanceAfterAction();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            updateId != null
                ? 'Updated ${spell.name}'
                : 'Saved ${spell.name}',
          ),
        ),
      );
      await _loadCatalog();
    } on AuthApiException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final draft = _current;
    final pendingCount = _pending.length;

    return Scaffold(
      appBar: AppBar(
        title: Text('Review spells (${widget.sourceFile.name})'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: Text(
                pendingCount == 0
                    ? 'Done'
                    : '${_index + 1} / ${_sorted.length} · $pendingCount left',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),
        ],
      ),
      body: _loadError != null
          ? Center(child: Text(_loadError!))
          : draft == null
              ? const Center(child: Text('No drafts left to review.'))
              : Column(
                  children: [
                    if (widget.sectionSummaries.isNotEmpty)
                      Material(
                        color: scheme.surfaceContainerHighest.withValues(
                          alpha: 0.4,
                        ),
                        child: SizedBox(
                          height: 40,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            children: [
                              for (final section in widget.sectionSummaries)
                                Padding(
                                  padding: const EdgeInsets.only(
                                    right: 8,
                                    top: 6,
                                    bottom: 6,
                                  ),
                                  child: Chip(
                                    visualDensity: VisualDensity.compact,
                                    label: Text(
                                      '${section.title ?? "Section"}: '
                                      '${section.entryCount} '
                                      '${section.healthOk ? "ok" : "tier ${section.tier}"}',
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    Expanded(
                      child: Row(
                        children: [
                          SizedBox(
                            width: 260,
                            child: ListView.builder(
                              itemCount: _sorted.length,
                              itemBuilder: (context, i) {
                                final item = _sorted[i];
                                final selected = i == _index;
                                return ListTile(
                                  selected: selected,
                                  dense: true,
                                  title: Text(
                                    item.displayName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      decoration: item.rejected
                                          ? TextDecoration.lineThrough
                                          : null,
                                    ),
                                  ),
                                  subtitle: Text(
                                    _draftSubtitle(item),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  leading: Icon(
                                    item.rejected
                                        ? Icons.block
                                        : item.riskScore >= 40
                                            ? Icons.warning_amber_outlined
                                            : Icons.check_circle_outline,
                                    color: item.rejected
                                        ? scheme.outline
                                        : item.riskScore >= 40
                                            ? scheme.error
                                            : scheme.primary,
                                  ),
                                  onTap: () => setState(() => _index = i),
                                );
                              },
                            ),
                          ),
                          const VerticalDivider(width: 1),
                          Expanded(
                            child: _DraftDetailPane(
                              draft: draft,
                              libraryMatchLabel: draft.libraryMatchName ??
                                  draft.libraryMatchId?.toString(),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            OutlinedButton.icon(
                              onPressed: _busy || draft.rejected
                                  ? null
                                  : _rejectCurrent,
                              icon: const Icon(Icons.close),
                              label: const Text('Reject'),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton.icon(
                              onPressed:
                                  _busy || draft.rejected ? null : _editCurrent,
                              icon: const Icon(Icons.edit_outlined),
                              label: const Text('Edit'),
                            ),
                            const Spacer(),
                            FilledButton.icon(
                              onPressed: _busy || draft.rejected
                                  ? null
                                  : _approveCurrent,
                              icon: _busy
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.check),
                              label: const Text('Approve'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }

  String _draftSubtitle(ExtractDraft draft) {
    final parts = <String>[
      'tier ${draft.tier}',
      draft.boundaryConfidence,
      if (draft.duplicateNameInLibrary) 'library dup',
      if (draft.duplicateNameInBatch) 'batch dup',
      if (draft.needsReview.isNotEmpty) draft.needsReview.first,
    ];
    return parts.join(' · ');
  }
}

enum _DupAction { discard, rename, overwrite }

class _DraftDetailPane extends StatelessWidget {
  const _DraftDetailPane({
    required this.draft,
    this.libraryMatchLabel,
  });

  final ExtractDraft draft;
  final String? libraryMatchLabel;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final payload = draft.payload;
    final flags = <String>[
      if (draft.duplicateNameInLibrary)
        'Library duplicate${libraryMatchLabel != null ? ": $libraryMatchLabel" : ""}',
      if (draft.duplicateNameInBatch) 'Duplicate name in this batch',
      ...draft.needsReview,
    ];

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Source text', style: textTheme.titleSmall),
                const SizedBox(height: 8),
                Expanded(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(12),
                      child: SelectableText(
                        draft.sourceText.isEmpty
                            ? '(empty)'
                            : draft.sourceText,
                        style: textTheme.bodySmall?.copyWith(
                          fontFamily: 'monospace',
                          height: 1.35,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Extracted fields', style: textTheme.titleSmall),
                const SizedBox(height: 8),
                if (flags.isNotEmpty) ...[
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final flag in flags)
                        Chip(
                          visualDensity: VisualDensity.compact,
                          label: Text(flag),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
                Expanded(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ListView(
                      padding: const EdgeInsets.all(12),
                      children: [
                        _field('Name', payload['name']),
                        _field('Level', payload['level']),
                        _field('School', payload['school']),
                        _field('Casting time', payload['castingTime']),
                        _field('Range', payload['range']),
                        _field('Components', payload['components']),
                        _field('Duration', payload['duration']),
                        _field('Classes', payload['classes']),
                        _field('Tags', payload['tags']),
                        _field('Description', payload['description']),
                        _field('Higher levels', payload['higherLevels']),
                        _field('Source page', payload['sourcePage']),
                        if (draft.notes != null && draft.notes!.isNotEmpty)
                          _field('Notes', draft.notes),
                        if (draft.unknownFields != null &&
                            draft.unknownFields!.isNotEmpty)
                          _field('Unknown fields', draft.unknownFields),
                        if (draft.source.section != null)
                          _field('Section', draft.source.section),
                        if (draft.source.page != null)
                          _field('Page', draft.source.page),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _field(String label, Object? value) {
    final text = value == null
        ? '—'
        : value is String
            ? (value.trim().isEmpty ? '—' : value)
            : value.toString();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
          ),
          const SizedBox(height: 2),
          SelectableText(text),
        ],
      ),
    );
  }
}
