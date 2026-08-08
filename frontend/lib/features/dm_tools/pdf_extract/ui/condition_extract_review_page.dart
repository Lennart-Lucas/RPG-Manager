import 'package:flutter/material.dart';

import '../../../auth/data/auth_api.dart';
import '../../../auth/state/auth_controller.dart';
import '../../../catalog/data/catalog_api.dart';
import '../../../catalog/data/catalog_auto_link.dart';
import '../../../catalog/data/catalog_kind.dart';
import '../../../catalog/data/catalog_models.dart';
import '../../../../core/ui/markdown_form_field.dart';
import '../../../../core/ui/mtg_card_rules_text_fit.dart';
import '../../../dm_tools/resources/data/local_resource_file_copy.dart';
import '../../../dm_tools/resources/data/resource_models.dart';
import '../../../mechanics/conditions/ui/condition_sheet.dart';
import '../../../mechanics/data/styled_mechanics_record.dart';
import '../../../mechanics/mechanics_icons.dart';
import '../../../mechanics/ui/styled_mechanics_ui.dart';
import '../data/condition_from_draft.dart';
import '../data/extract_models.dart';

class ConditionExtractReviewPage extends StatefulWidget {
  const ConditionExtractReviewPage({
    super.key,
    required this.auth,
    required this.sourceFile,
    required this.localPath,
    required this.drafts,
    required this.sectionSummaries,
  });

  final AuthController auth;
  final ResourceFile sourceFile;
  final String localPath;
  final List<ExtractDraft> drafts;
  final List<ExtractSectionSummary> sectionSummaries;

  @override
  State<ConditionExtractReviewPage> createState() =>
      _ConditionExtractReviewPageState();
}

enum _ReviewFilter { all, hard, soft, complete, junk }

class _ConditionExtractReviewPageState
    extends State<ConditionExtractReviewPage> {
  final _catalogApi = CatalogApi();
  final _fileCopy = LocalResourceFileCopy();

  late List<ExtractDraft> _drafts;
  late List<ExtractDraft> _sorted;
  int _index = 0;
  bool _busy = false;
  bool _hideJunk = false;
  _ReviewFilter _filter = _ReviewFilter.all;
  String? _sectionFilter;
  List<CatalogItem> _existingConditions = const [];
  List<CatalogLinkTarget> _autoLinkTargets = const [];
  String? _loadError;

  ExtractDraft? get _current {
    if (_sorted.isEmpty || _index < 0 || _index >= _sorted.length) return null;
    return _sorted[_index];
  }

  List<ExtractDraft> get _pending =>
      _drafts.where((d) => !d.rejected).toList(growable: false);

  int get _junkPendingCount =>
      _drafts.where((d) => !d.rejected && d.isJunk).length;

  @override
  void initState() {
    super.initState();
    _drafts = List<ExtractDraft>.from(widget.drafts);
    _resort();
    _loadCatalog();
  }

  bool _matchesFilters(ExtractDraft d) {
    if (_hideJunk && d.isJunk) return false;
    if (_sectionFilter != null) {
      final section = d.source.section ?? '';
      if (section != _sectionFilter) return false;
    }
    switch (_filter) {
      case _ReviewFilter.all:
        return true;
      case _ReviewFilter.hard:
        return d.isHardReviewIssue && !d.rejected;
      case _ReviewFilter.soft:
        return d.isSoftReviewOnly && !d.rejected;
      case _ReviewFilter.complete:
        return d.isCompleteClean && !d.rejected;
      case _ReviewFilter.junk:
        return d.isJunk;
    }
  }

  void _resort() {
    _sorted = _drafts.where(_matchesFilters).toList()
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

  Future<void> _rejectAllJunk() async {
    final count = _junkPendingCount;
    if (count == 0) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject all non-conditions?'),
        content: Text(
          'Mark $count draft${count == 1 ? '' : 's'} flagged '
          'not_a_condition as rejected. You can still find them via the Junk filter.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reject all'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() {
      for (final d in _drafts) {
        if (d.isJunk) d.rejected = true;
      }
      _resort();
      _advanceAfterAction();
    });
  }

  Future<String?> _token() => widget.auth.requireAccessToken();

  Future<void> _loadCatalog() async {
    try {
      final token = await _token();
      if (token == null) return;
      final conditions = await _catalogApi.list(token, CatalogKind.conditions);
      final autoLinkTargets =
          await loadConditionDamageAutoLinkTargets(_catalogApi, token);
      if (!mounted) return;
      setState(() {
        _existingConditions = conditions;
        _autoLinkTargets = autoLinkTargets;
        _loadError = null;
      });
    } on AuthApiException catch (e) {
      if (!mounted) return;
      setState(() => _loadError = e.message);
    }
  }

  Future<List<CatalogLinkTarget>> _searchLinks(String query) async {
    final token = await _token();
    if (token == null) return const [];
    return searchCatalogLinkTargets(_catalogApi, token, query);
  }

  CatalogItem? _findLibraryItem(String name) {
    final key = name.trim().toLowerCase();
    for (final item in _existingConditions) {
      if (item.name.trim().toLowerCase() == key) return item;
    }
    return null;
  }

  Future<void> _openLocalFile() async {
    try {
      await _fileCopy.openLocalPath(widget.localPath);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open local file')),
      );
    }
  }

  Future<void> _editCurrent() async {
    final draft = _current;
    if (draft == null || draft.rejected) return;
    final record = conditionFromExtractDraft(
      draft: draft,
      sourceFileId: widget.sourceFile.id,
    );
    final edited = await showStyledMechanicsFormSheet(
      context,
      singularLabel: 'condition',
      fallbackIcon: conditionsPageIcon,
      defaultIconKey: 'monitor_heart',
      initial: record,
      resourceFiles: [widget.sourceFile],
      searchLinks: _searchLinks,
      loadAutoLinkTargets: () async => _autoLinkTargets,
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

    var record = conditionFromExtractDraft(
      draft: draft,
      sourceFileId: widget.sourceFile.id,
    );

    final existing = _findLibraryItem(record.name);
    if (existing != null || draft.duplicateNameInLibrary) {
      final match = existing ??
          (draft.libraryMatchId != null
              ? CatalogItem(
                  id: draft.libraryMatchId!,
                  userId: 0,
                  kind: CatalogKind.conditions,
                  name: draft.libraryMatchName ?? record.name,
                )
              : null);
      final action = await showDialog<_DupAction>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Name already in library'),
          content: Text(
            '"${record.name}" already exists'
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
        final renamed = await _promptRename(record.name);
        if (renamed == null || !mounted) return;
        record = record.copyWith(name: renamed);
      }
      if (action == _DupAction.overwrite && match != null) {
        await _commit(
          record: record,
          updateId: match.id,
          draft: draft,
        );
        return;
      }
    }

    if (draft.duplicateNameInBatch) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Duplicate in this batch'),
          content: Text(
            'Another draft in this import also uses "${record.name}". '
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

    await _commit(record: record, draft: draft);
  }

  Future<String?> _promptRename(String current) async {
    final controller = TextEditingController(text: '$current (import)');
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename condition'),
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
    required StyledMechanicsRecord record,
    required ExtractDraft draft,
    int? updateId,
  }) async {
    setState(() => _busy = true);
    try {
      final token = await _token();
      if (token == null) return;
      var targets = _autoLinkTargets;
      if (targets.isEmpty) {
        targets = await loadConditionDamageAutoLinkTargets(_catalogApi, token);
        if (mounted) setState(() => _autoLinkTargets = targets);
      }
      final linked = autoLinkStyledMechanicsFields(record, targets).value;
      if (updateId != null) {
        await _catalogApi.update(
          accessToken: token,
          kind: CatalogKind.conditions,
          itemId: updateId,
          name: linked.name,
          payload: linked.toJson(),
        );
      } else {
        await _catalogApi.create(
          accessToken: token,
          kind: CatalogKind.conditions,
          name: linked.name,
          payload: linked.toJson(),
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
                ? 'Updated ${linked.name}'
                : 'Saved ${linked.name}',
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
    final junkCount = _junkPendingCount;
    final emptyMessage = _drafts.isEmpty
        ? 'No drafts left to review.'
        : 'No drafts match the current filters.';

    return Scaffold(
      appBar: AppBar(
        title: Text('Review conditions (${widget.sourceFile.name})'),
        actions: [
          IconButton(
            tooltip: 'Open local file',
            onPressed: _openLocalFile,
            icon: const Icon(Icons.open_in_new),
          ),
          if (junkCount > 0)
            TextButton(
              onPressed: _busy ? null : _rejectAllJunk,
              child: Text('Reject junk ($junkCount)'),
            ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: Text(
                pendingCount == 0
                    ? 'Done'
                    : '${_sorted.isEmpty ? 0 : _index + 1} / ${_sorted.length}'
                        ' · $pendingCount left',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),
        ],
      ),
      body: _loadError != null
          ? Center(child: Text(_loadError!))
          : Column(
              children: [
                Material(
                  color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          height: 36,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            children: [
                              for (final entry in const [
                                (_ReviewFilter.all, 'All'),
                                (_ReviewFilter.hard, 'Hard'),
                                (_ReviewFilter.soft, 'Soft'),
                                (_ReviewFilter.complete, 'Complete'),
                                (_ReviewFilter.junk, 'Junk'),
                              ])
                                Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: FilterChip(
                                    visualDensity: VisualDensity.compact,
                                    label: Text(entry.$2),
                                    selected: _filter == entry.$1,
                                    onSelected: (_) => setState(() {
                                      _filter = entry.$1;
                                      _index = 0;
                                      _resort();
                                    }),
                                  ),
                                ),
                              const SizedBox(width: 8),
                              FilterChip(
                                visualDensity: VisualDensity.compact,
                                label: const Text('Hide junk'),
                                selected: _hideJunk,
                                onSelected: (v) => setState(() {
                                  _hideJunk = v;
                                  if (v && _filter == _ReviewFilter.junk) {
                                    _filter = _ReviewFilter.all;
                                  }
                                  _index = 0;
                                  _resort();
                                }),
                              ),
                            ],
                          ),
                        ),
                        if (widget.sectionSummaries.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          SizedBox(
                            height: 36,
                            child: ListView(
                              scrollDirection: Axis.horizontal,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: FilterChip(
                                    visualDensity: VisualDensity.compact,
                                    label: const Text('All sections'),
                                    selected: _sectionFilter == null,
                                    onSelected: (_) => setState(() {
                                      _sectionFilter = null;
                                      _index = 0;
                                      _resort();
                                    }),
                                  ),
                                ),
                                for (final section in widget.sectionSummaries)
                                  Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: FilterChip(
                                      visualDensity: VisualDensity.compact,
                                      selected: _sectionFilter ==
                                          (section.title ?? ''),
                                      label: Text(
                                        '${section.title ?? "Section"}: '
                                        '${section.entryCount} '
                                        '${section.healthOk ? "ok" : "tier ${section.tier}"}',
                                      ),
                                      onSelected: (_) => setState(() {
                                        final key = section.title ?? '';
                                        _sectionFilter =
                                            _sectionFilter == key ? null : key;
                                        _index = 0;
                                        _resort();
                                      }),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: draft == null
                      ? Center(child: Text(emptyMessage))
                      : Row(
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
                                          : item.isJunk
                                              ? Icons.not_interested
                                              : item.isHardReviewIssue
                                                  ? Icons.warning_amber_outlined
                                                  : Icons.check_circle_outline,
                                      color: item.rejected
                                          ? scheme.outline
                                          : item.isHardReviewIssue
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
                              child: Builder(
                                builder: (context) {
                                  final record = conditionFromExtractDraft(
                                    draft: draft,
                                    sourceFileId: widget.sourceFile.id,
                                  );
                                  return _DraftDetailPane(
                                    auth: widget.auth,
                                    draft: draft,
                                    record: record,
                                    libraryMatchLabel:
                                        draft.libraryMatchName ??
                                            draft.libraryMatchId?.toString(),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                ),
                if (draft != null) ...[
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
    required this.auth,
    required this.draft,
    required this.record,
    this.libraryMatchLabel,
  });

  final AuthController auth;
  final ExtractDraft draft;
  final StyledMechanicsRecord record;
  final String? libraryMatchLabel;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final flags = <String>[
      if (draft.duplicateNameInLibrary)
        'Library duplicate${libraryMatchLabel != null ? ": $libraryMatchLabel" : ""}',
      if (draft.duplicateNameInBatch) 'Duplicate name in this batch',
      ...draft.needsReview,
    ];
    final notes = draft.notes?.trim();
    final hasNotes = notes != null && notes.isNotEmpty;
    final unknown = draft.unknownFields;
    final hasUnknown = unknown != null && unknown.isNotEmpty;

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
                  flex: hasNotes || hasUnknown ? 3 : 1,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border.all(color: scheme.outlineVariant),
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
                if (hasNotes ||
                    hasUnknown ||
                    draft.source.section != null ||
                    draft.source.page != null) ...[
                  const SizedBox(height: 12),
                  Text('Notes & meta', style: textTheme.titleSmall),
                  const SizedBox(height: 8),
                  Expanded(
                    flex: 2,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        border: Border.all(color: scheme.outlineVariant),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ListView(
                        padding: const EdgeInsets.all(12),
                        children: [
                          if (hasNotes) _field('Notes', notes),
                          if (hasUnknown) _field('Unknown fields', unknown),
                          if (draft.source.section != null)
                            _field('Section', draft.source.section),
                          if (draft.source.page != null)
                            _field('Page', draft.source.page),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Condition preview', style: textTheme.titleSmall),
                const SizedBox(height: 8),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
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
                          const SizedBox(height: 12),
                        ],
                        for (final card in buildConditionSheets(
                          record,
                          cardScale: 0.95,
                          maxFontSize: kMtgCardRulesMaxFontSize * 0.95,
                        ))
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Align(
                              alignment: Alignment.topCenter,
                              child: SizedBox(
                                width: 340,
                                child: card,
                              ),
                            ),
                          ),
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
