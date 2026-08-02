import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:random_table_engine/generation_engine.dart';

import '../../../auth/data/auth_api.dart';
import '../../../auth/state/auth_controller.dart';
import '../../../catalog/data/catalog_kind.dart';
import '../../../catalog/data/catalog_models.dart';
import '../../../catalog/ui/open_catalog_detail.dart';
import '../data/generator_apply_service.dart';
import '../data/generator_input_spec.dart';
import '../data/generator_model.dart';
import '../data/generator_record_mapping.dart';

Future<void> showGeneratorRunWorkspace(
  BuildContext context, {
  required GeneratorRecord record,
  required AuthController auth,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => GeneratorRunWorkspace(record: record, auth: auth),
  );
}

/// Generate workspace: pin/roll fields, generate in place, Apply.
class GeneratorRunWorkspace extends StatefulWidget {
  const GeneratorRunWorkspace({
    super.key,
    required this.record,
    required this.auth,
  });

  final GeneratorRecord record;
  final AuthController auth;

  @override
  State<GeneratorRunWorkspace> createState() => _GeneratorRunWorkspaceState();
}

class _GeneratorRunWorkspaceState extends State<GeneratorRunWorkspace> {
  late final TableRegistry _registry;
  late final GenerationProcess _process;
  late final GeneratorInputSpec _spec;
  late final GeneratorRunSession _session = GeneratorRunSession();
  late final Roller _roller = RandomRoller();
  final _applyService = GeneratorApplyService();

  String? _buildError;
  final Map<String, bool> _pulse = {};
  Timer? _chromeRefreshTimer;

  List<GeneratedRecord> _records = const [];
  String? _resultsError;
  bool _applying = false;
  bool _applyPanelExpanded = false;
  List<GeneratorAppliedItem>? _applied;
  bool get _hasPreview => _records.isNotEmpty;

  @override
  void dispose() {
    _chromeRefreshTimer?.cancel();
    super.dispose();
  }

  /// Rebuild banners/plan chips without interrupting an active text edit.
  void _scheduleChromeRefresh() {
    _chromeRefreshTimer?.cancel();
    _chromeRefreshTimer = Timer(const Duration(milliseconds: 350), () {
      if (mounted) setState(() {});
    });
  }

  List<CatalogItem>? _parentChoices;
  CatalogKind? _parentChoiceKind;
  int? _selectedParentId;
  bool _loadingParents = false;
  String? _parentLoadError;

  GeneratorRecordMapping get _mapping => widget.record.recordMappingOrEmpty;

  @override
  void initState() {
    super.initState();
    try {
      _registry = TableRegistry.fromJson(widget.record.tablesDocument);
      _process = GenerationProcess.fromJson(widget.record.processDocument);
      _spec = GeneratorInputSpec.fromProcess(
        process: _process,
        registry: _registry,
      );
    } catch (e) {
      _buildError = '$e';
    }
  }

  void _clearAll() {
    setState(() {
      _session.clear();
      _pulse.clear();
      _records = const [];
      _resultsError = null;
      _applied = null;
      _applyPanelExpanded = false;
      _selectedParentId = null;
      _parentChoices = null;
      _parentChoiceKind = null;
      _parentLoadError = null;
    });
  }

  Future<void> _pulseKey(String key) async {
    setState(() => _pulse[key] = true);
    await Future<void>.delayed(const Duration(milliseconds: 180));
    if (!mounted) return;
    setState(() => _pulse[key] = false);
  }

  String? _rollTable(String tableId) {
    try {
      return _registry.get(tableId).roll(_roller, _registry).value;
    } catch (_) {
      return null;
    }
  }

  int? _rollLookupCount(GeneratorCountSource source) {
    try {
      final lookup = _registry.getLookup(source.tableId);
      final keyField = source.keyField;
      String? key;
      if (keyField != null) {
        final pinned = _session.fieldPins[keyField];
        if (pinned != null && pinned.isNotEmpty) {
          key = pinned;
        }
      }
      if (key == null || key.isEmpty) {
        final keyTable = source.keyTableId;
        if (keyTable != null) {
          key = _rollTable(keyTable);
        }
      }
      if (key == null || key.isEmpty) {
        final keys = lookup.values.keys.toList(growable: false);
        if (keys.isEmpty) return null;
        key = keys[_roller.roll(keys.length) - 1];
      }
      return lookup.resolve(key, _roller);
    } catch (_) {
      return null;
    }
  }

  Future<void> _rollCollectionCount(GeneratorCollectionInput node) async {
    final source = node.countSource;
    if (source == null) return;
    int? value;
    if (source.kind == GeneratorScalarKind.roll) {
      final rolled = _rollTable(source.tableId);
      value = int.tryParse(rolled ?? '');
    } else {
      value = _rollLookupCount(source);
    }
    if (value == null) return;
    setState(() {
      _session.setCollectionCount(
        node.id,
        value,
        countField: node.countField,
      );
    });
    await _pulseKey('${node.id}#count');
  }

  void _pinField(String id, String? value, {bool rebuild = true}) {
    _session.setFieldPin(id, value);
    final root = _root;
    if (root != null) {
      final trimmed = value?.trim();
      if (trimmed == null || trimmed.isEmpty) {
        root.fields.remove(id);
      } else {
        root.fields[id] = trimmed;
      }
    }
    if (rebuild) {
      setState(() {});
    } else {
      _scheduleChromeRefresh();
    }
  }

  Future<void> _rollField(GeneratorScalarInput node) async {
    final value = _rollTable(node.tableId);
    if (value == null) return;
    _pinField(node.id, value);
    await _pulseKey(node.id);
  }

  Future<void> _rollGate(GeneratorGateInput node) async {
    final value = _rollTable(node.tableId);
    if (value == null) return;
    _pinField(node.id, value);
    await _pulseKey(node.id);
  }

  void _setSlotPin(
    GeneratorCollectionInput node,
    int index,
    String? value, {
    bool rebuild = true,
  }) {
    _session.setSlotPin(
      node.id,
      index,
      value,
      countField: node.countField,
    );
    final children = [
      for (final r in _records)
        if (r.parentField == node.id) r,
    ];
    if (index < children.length) {
      final child = children[index];
      final key = GeneratorRunSession.preferredNameFieldKey(child);
      final trimmed = value?.trim();
      if (trimmed == null || trimmed.isEmpty) {
        child.fields.remove(key);
      } else {
        child.fields[key] = trimmed;
        if (key != 'value' && child.fields.containsKey('value')) {
          child.fields['value'] = trimmed;
        }
        if (key != 'name') {
          child.fields['name'] = trimmed;
        }
      }
    }
    if (rebuild) {
      setState(() {});
    } else {
      _scheduleChromeRefresh();
    }
  }

  Future<void> _rollSlot(GeneratorCollectionInput node, int index) async {
    final value = _rollTable(node.tableId);
    if (value == null) return;
    _setSlotPin(node, index, value);
    await _pulseKey('${node.id}#$index');
  }

  void _runPreview() {
    try {
      _records = widget.record.runPreview(overrides: _session.toOverrides());
      _session.hydrateFromRecords(records: _records, nodes: _spec.nodes);
      _resultsError = null;
      _applied = null;
      _applyPanelExpanded = false;
      _selectedParentId = null;
      _parentChoices = null;
      _parentChoiceKind = null;
      _parentLoadError = null;
    } catch (e) {
      _records = const [];
      _resultsError = '$e';
      _applied = null;
    }
  }

  void _generate() {
    setState(_runPreview);
    _maybeLoadParents();
  }

  void _setRecordNameField(
    GeneratedRecord record,
    String nameFrom,
    String raw, {
    bool rebuild = true,
  }) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      record.fields.remove(nameFrom);
    } else {
      record.fields[nameFrom] = trimmed;
    }
    if (record.parentId == null && nameFrom == 'name') {
      _session.setFieldPin('name', trimmed.isEmpty ? null : trimmed);
    }
    final parentField = record.parentField;
    if (parentField != null) {
      final siblings = [
        for (final r in _records)
          if (r.parentField == parentField) r,
      ];
      final index = siblings.indexWhere((r) => r.id == record.id);
      if (index >= 0) {
        _session.setSlotPin(
          parentField,
          index,
          trimmed.isEmpty ? null : trimmed,
        );
      }
    }
    if (rebuild) {
      setState(() {});
    } else {
      _scheduleChromeRefresh();
    }
  }

  List<GeneratedRecord> get _orphanRecords {
    final covered = GeneratorRunSession.collectionIdsIn(_spec.nodes);
    return [
      for (final r in _records)
        if (r.parentId != null &&
            (r.parentField == null || !covered.contains(r.parentField)))
          r,
    ];
  }

  List<GeneratedRecord> _childrenForCollection(String collectionId) {
    return [
      for (final r in _records)
        if (r.parentField == collectionId) r,
    ];
  }

  Map<String, int> get _typeCounts {
    final counts = <String, int>{};
    for (final r in _records) {
      counts.update(r.type, (v) => v + 1, ifAbsent: () => 1);
    }
    return counts;
  }

  GeneratedRecord? get _root {
    if (_records.isEmpty) return null;
    for (final r in _records) {
      if (r.parentId == null) return r;
    }
    return _records.first;
  }

  List<GeneratedRecord> get _applyPlan => recordsToApplyInOrder(
        records: _records,
        mapping: _mapping,
        processRecordType: widget.record.recordTypeLabel,
      );

  List<GeneratorApplyPlanEntry> get _applyPlanEntries => _mapping.buildApplyPlan(
        records: _records,
        processRecordType: widget.record.recordTypeLabel,
      );

  Map<String, GeneratorApplyPlanEntry> get _applyPlanById => {
        for (final e in _applyPlanEntries) e.genId: e,
      };

  bool get _needsExternalParent => _mapping.needsExternalParent(
        _root,
        allRecords: _records,
        processRecordType: widget.record.recordTypeLabel,
      );

  CatalogKind? get _parentPickerKind => _mapping.externalParentPickerKind(
        _root,
        allRecords: _records,
        processRecordType: widget.record.recordTypeLabel,
      );

  String? get _applyBlockedReason {
    if (_applying) return 'Apply is already in progress.';
    if (_resultsError != null) {
      return 'Fix the generation error before applying.';
    }
    final parseError = () {
      try {
        final raw = widget.record.recordMappingDocument;
        if (raw == null) return null;
        return GeneratorRecordMapping.fromJson(raw).validate();
      } catch (e) {
        return '$e';
      }
    }();
    if (parseError != null) return 'Record mapping error: $parseError';
    if (!_mapping.hasBindings) {
      return 'No record mapping bindings saved on this generator. '
          'Edit the generator → Record mapping JSON, add bindings, Save, '
          'then Generate again.';
    }
    if (_applyPlan.isEmpty) {
      final types = _typeCounts.keys.join(', ');
      final matches = _mapping.bindings.map((b) => b.matchType).join(', ');
      final processType = widget.record.recordTypeLabel;
      final processInResults = _typeCounts.containsKey(processType);
      final processInBindings =
          _mapping.bindings.any((b) => b.matchType == processType);
      final suggestion = processInResults && !processInBindings
          ? ' Tip: process recordType is "$processType" — set binding '
              'matchType to "$processType", or for locations use a catalog '
              'type name like "city" as matchType to alias the root.'
          : '';
      return 'No results match the mapping. '
          'Result types: [${types.isEmpty ? 'none' : types}]. '
          'Binding matchTypes: [$matches]. '
          'They must match process recordType / emitAs exactly.$suggestion';
    }
    return null;
  }

  Future<void> _maybeLoadParents() async {
    if (!_needsExternalParent) return;
    final kind = _parentPickerKind;
    if (kind == null) return;
    if (_parentChoices != null && _parentChoiceKind == kind) return;

    setState(() {
      _loadingParents = true;
      _parentLoadError = null;
      _parentChoiceKind = kind;
    });
    try {
      final token = await widget.auth.requireAccessToken();
      if (token == null || !mounted) return;
      final items = await _applyService.listForParentPicker(
        accessToken: token,
        kind: kind,
      );
      if (!mounted) return;
      setState(() {
        _parentChoices = items;
        _loadingParents = false;
      });
    } on AuthApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingParents = false;
        _parentLoadError = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingParents = false;
        _parentLoadError = '$e';
      });
    }
  }

  void _openApplyPanel() {
    final blocked = _applyBlockedReason;
    if (blocked != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(blocked)));
      return;
    }
    setState(() => _applyPanelExpanded = true);
    _maybeLoadParents();
  }

  Future<void> _confirmApply() async {
    final blocked = _applyBlockedReason;
    if (blocked != null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(blocked)));
      return;
    }
    if (_applying || _resultsError != null) return;
    final plan = _applyPlan;
    if (plan.isEmpty) return;

    setState(() => _applying = true);
    try {
      final token = await widget.auth.requireAccessToken();
      if (token == null || !mounted) return;
      final result = await _applyService.apply(
        accessToken: token,
        records: _records,
        mapping: _mapping,
        rootParentCatalogId: _needsExternalParent ? _selectedParentId : null,
        processRecordType: widget.record.recordTypeLabel,
      );
      if (!mounted) return;
      setState(() {
        _applied = result.created;
        _applyPanelExpanded = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Created ${result.created.length} catalog '
            'record${result.created.length == 1 ? '' : 's'}',
          ),
        ),
      );
    } on GeneratorApplyException catch (e) {
      if (!mounted) return;
      if (e.partial.isNotEmpty) {
        setState(() => _applied = e.partial);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } on AuthApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Apply failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _applying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final height = MediaQuery.sizeOf(context).height * 0.92;

    if (_buildError != null) {
      return SizedBox(
        height: height * 0.4,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Could not build generate form:\n$_buildError',
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.error),
            ),
          ),
        ),
      );
    }

    final blockedReason = _hasPreview ? _applyBlockedReason : null;
    final applyCount = _applyPlan.length;
    final orphans = _orphanRecords;

    return SizedBox(
      height: height,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.record.name,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  _resultsError != null
                      ? 'Generation failed — adjust inputs and try again.'
                      : _hasPreview
                          ? '${_records.length} record'
                              '${_records.length == 1 ? '' : 's'} — '
                              'edit fields below or Apply.'
                          : 'Set what you know, leave the rest on Auto, then Generate.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(child: _buildBody(scheme, blockedReason, applyCount, orphans)),
          if (_applyPanelExpanded)
            _ApplyPanel(
              planEntries: _applyPlanEntries,
              warnings: widget.record.applyWarnings(sampleRecords: _records),
              needsParent: _needsExternalParent,
              parentKind: _parentPickerKind,
              parentChoices: _parentChoices,
              loadingParents: _loadingParents,
              parentLoadError: _parentLoadError,
              selectedParentId: _selectedParentId,
              applying: _applying,
              onParentChanged: (id) => setState(() => _selectedParentId = id),
              onCancel: () => setState(() => _applyPanelExpanded = false),
              onConfirm: _confirmApply,
            )
          else
            _buildFooter(scheme),
        ],
      ),
    );
  }

  Widget _buildBody(
    ColorScheme scheme,
    String? blockedReason,
    int applyCount,
    List<GeneratedRecord> orphans,
  ) {
    if (_spec.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'This process has no fillable steps yet.\n'
            'Add roll / lookup / rollMany / gate steps in the config.',
            textAlign: TextAlign.center,
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        if (_resultsError != null)
          _StatusBanner(text: _resultsError!, tone: _StatusTone.warning)
        else if (blockedReason != null)
          _StatusBanner(text: blockedReason, tone: _StatusTone.warning)
        else if (_hasPreview && _mapping.hasBindings && applyCount > 0)
          _StatusBanner(
            text:
                'Ready to create $applyCount catalog record${applyCount == 1 ? '' : 's'}.',
            tone: _StatusTone.info,
          ),
        if (_applied != null && _applied!.isNotEmpty) ...[
          Text(
            'Created in catalog',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 4),
          for (final item in _applied!)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(item.name),
              subtitle: Text(item.kind.singularLabel),
              trailing: const Icon(Icons.open_in_new, size: 18),
              onTap: () => openCatalogRecordDetail(
                context: context,
                auth: widget.auth,
                kindApiValue: item.kind.apiValue,
                itemId: item.catalogId,
              ),
            ),
          const SizedBox(height: 8),
        ],
        if (widget.record.recordMappingError != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              'Record mapping error: ${widget.record.recordMappingError}',
              style: TextStyle(color: scheme.error),
            ),
          ),
        if (_hasPreview)
          for (final w in widget.record.applyWarnings(sampleRecords: _records))
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                w,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.tertiary,
                    ),
              ),
            ),
        if (_session.hasSparseCollectionPins)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              'A pin sits after an Auto slot in a collection. '
              'Only a leading pin prefix is applied — fill or '
              'clear earlier Auto slots first.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.tertiary,
                  ),
            ),
          ),
        for (final node in _spec.nodes)
          KeyedSubtree(
            key: ValueKey('gen-node-${node.id}'),
            child: _buildNode(node),
          ),
        if (orphans.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            'Other generated records',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),
          for (final orphan in orphans)
            KeyedSubtree(
              key: ValueKey('gen-orphan-${orphan.id}'),
              child: _OrphanRecordCard(
                record: orphan,
                plan: _applyPlanById[orphan.id],
                onNameChanged: (record, nameFrom, value) =>
                    _setRecordNameField(record, nameFrom, value, rebuild: false),
              ),
            ),
        ],
      ],
    );
  }

  Widget _buildFooter(ColorScheme scheme) {
    final blocked = _hasPreview ? _applyBlockedReason : 'Generate first.';
    final canApply = _hasPreview && blocked == null;

    return Material(
      elevation: 6,
      color: scheme.surface,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            children: [
              TextButton(
                onPressed: (_session.hasPins || _hasPreview) && !_applying
                    ? _clearAll
                    : null,
                child: const Text('Clear all'),
              ),
              const Spacer(),
              FilledButton.tonalIcon(
                onPressed: _applying ? null : _generate,
                icon: Icon(_hasPreview ? Icons.refresh : Icons.play_arrow),
                label: Text(_hasPreview ? 'Again' : 'Generate'),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: _applying || !_hasPreview ? null : _openApplyPanel,
                style: FilledButton.styleFrom(
                  backgroundColor:
                      canApply ? null : scheme.surfaceContainerHighest,
                  foregroundColor: canApply
                      ? null
                      : scheme.onSurface.withValues(alpha: 0.38),
                ),
                icon: const Icon(Icons.save_outlined, size: 18),
                label: const Text('Apply'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNode(GeneratorInputNode node) {
    return switch (node) {
      GeneratorScalarInput() => _ScalarRow(
          node: node,
          pinned: _session.fieldPins[node.id],
          pulsing: _pulse[node.id] == true,
          onClear: () => _pinField(node.id, null),
          onRoll: node.canRoll ? () => _rollField(node) : null,
          onChanged: (v) => _pinField(node.id, v, rebuild: false),
          preferText: node.prefersTextInput,
          plan: node.id == 'name' && _root != null
              ? _applyPlanById[_root!.id]
              : null,
        ),
      GeneratorGateInput() => _GateBlock(
          node: node,
          pinned: _session.fieldPins[node.id],
          pulsing: _pulse[node.id] == true,
          showThen: _session.fieldPins[node.id] == node.proceedValue,
          onClear: () => _pinField(node.id, null),
          onRoll: () => _rollGate(node),
          onChanged: (v) => _pinField(node.id, v, rebuild: false),
          thenChildren: [
            for (final child in node.thenNodes)
              KeyedSubtree(
                key: ValueKey('gen-node-${child.id}'),
                child: _buildNode(child),
              ),
          ],
        ),
      GeneratorCollectionInput() => _CollectionBlock(
          node: node,
          count: _session.collectionCounts[node.id],
          slots: _session.collectionSlots[node.id] ?? const [],
          slotCount: _session.slotCountFor(node.id),
          knownFloor: _session.knownSlotFloor(node.id),
          pulse: _pulse,
          slotPlans: [
            for (final child in _childrenForCollection(node.id))
              _applyPlanById[child.id],
          ],
          onCountChanged: (c) => setState(
            () => _session.setCollectionCount(
              node.id,
              c,
              countField: node.countField,
            ),
          ),
          onClearCount: () => setState(
            () => _session.setCollectionCount(
              node.id,
              null,
              countField: node.countField,
            ),
          ),
          onRollCount:
              node.canRollCount ? () => _rollCollectionCount(node) : null,
          onAddKnown: () => setState(
            () => _session.addKnownSlot(
              node.id,
              countField: node.countField,
            ),
          ),
          onSlotClear: (i) => _setSlotPin(node, i, null),
          onSlotRoll: (i) => _rollSlot(node, i),
          onSlotChanged: (i, v) => _setSlotPin(node, i, v, rebuild: false),
        ),
    };
  }
}

enum _StatusTone { info, warning }

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.text, required this.tone});

  final String text;
  final _StatusTone tone;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = tone == _StatusTone.warning
        ? scheme.tertiaryContainer.withValues(alpha: 0.55)
        : scheme.secondaryContainer.withValues(alpha: 0.45);
    final fg = tone == _StatusTone.warning
        ? scheme.onTertiaryContainer
        : scheme.onSecondaryContainer;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: fg),
      ),
    );
  }
}

/// Searchable option menu anchored to a field (no nested bottom sheet).
class _OptionMenuField extends StatefulWidget {
  const _OptionMenuField({
    required this.identity,
    required this.value,
    required this.options,
    required this.onChanged,
    this.hintText = 'Auto',
    this.labelText,
    this.preferText = false,
  });

  final String identity;
  final String? value;
  final List<String> options;
  final ValueChanged<String?> onChanged;
  final String hintText;
  final String? labelText;
  final bool preferText;

  @override
  State<_OptionMenuField> createState() => _OptionMenuFieldState();
}

class _OptionMenuFieldState extends State<_OptionMenuField> {
  final MenuController _menu = MenuController();
  final FocusNode _focusNode = FocusNode();
  late final TextEditingController _controller;
  late final TextEditingController _filterController;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value ?? '');
    _filterController = TextEditingController();
  }

  @override
  void didUpdateWidget(covariant _OptionMenuField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.identity != widget.identity) {
      _controller.text = widget.value ?? '';
      return;
    }
    // Never clobber in-progress typing when a parent rebuild arrives.
    if (_focusNode.hasFocus) return;
    final next = widget.value ?? '';
    if (next != _controller.text) {
      _controller.text = next;
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _controller.dispose();
    _filterController.dispose();
    super.dispose();
  }

  void _pick(String? value) {
    widget.onChanged(value);
    _controller.text = value ?? '';
    _filterController.clear();
    _menu.close();
    setState(() {});
  }

  List<String> _filtered() {
    final needle = _filterController.text.trim().toLowerCase();
    if (needle.isEmpty) return widget.options;
    return [
      for (final o in widget.options)
        if (o.toLowerCase().contains(needle)) o,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final pinned = _controller.text.trim().isNotEmpty;
    final hasOptions = widget.options.isNotEmpty;

    Widget field;
    if (widget.preferText || !hasOptions) {
      field = TextField(
        focusNode: _focusNode,
        controller: _controller,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(
          isDense: true,
          labelText: widget.labelText,
          hintText: widget.hintText,
          hintStyle: TextStyle(
            fontStyle: FontStyle.italic,
            color: scheme.onSurfaceVariant,
          ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          filled: true,
          fillColor: pinned
              ? scheme.primaryContainer.withValues(alpha: 0.35)
              : scheme.surfaceContainerHighest.withValues(alpha: 0.35),
          suffixIcon: hasOptions
              ? IconButton(
                  tooltip: 'Choose from table',
                  onPressed: () {
                    _filterController.text = _controller.text;
                    _menu.open();
                  },
                  icon: const Icon(Icons.arrow_drop_down),
                )
              : null,
        ),
        onChanged: (raw) {
          final trimmed = raw.trim();
          widget.onChanged(trimmed.isEmpty ? null : raw.trimRight());
          setState(() {});
        },
      );
    } else {
      field = Material(
        color: pinned
            ? scheme.primaryContainer.withValues(alpha: 0.35)
            : scheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () {
            _filterController.clear();
            _menu.open();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: pinned
                    ? scheme.primary.withValues(alpha: 0.45)
                    : scheme.outlineVariant,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    pinned ? widget.value! : widget.hintText,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: pinned
                              ? scheme.onSurface
                              : scheme.onSurfaceVariant,
                          fontStyle:
                              pinned ? FontStyle.normal : FontStyle.italic,
                          fontWeight:
                              pinned ? FontWeight.w600 : FontWeight.w400,
                        ),
                  ),
                ),
                Icon(
                  Icons.arrow_drop_down,
                  color: scheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return MenuAnchor(
      controller: _menu,
      alignmentOffset: const Offset(0, 4),
      style: MenuStyle(
        maximumSize: WidgetStatePropertyAll(
          Size(
            math.min(MediaQuery.sizeOf(context).width - 48, 420),
            320,
          ),
        ),
        padding: const WidgetStatePropertyAll(EdgeInsets.zero),
      ),
      menuChildren: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
          child: TextField(
            controller: _filterController,
            autofocus: true,
            decoration: InputDecoration(
              isDense: true,
              hintText: hasOptions ? 'Search or type' : 'Type a value',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                tooltip: 'Use typed value',
                onPressed: () {
                  final t = _filterController.text.trim();
                  _pick(t.isEmpty ? null : t);
                },
                icon: const Icon(Icons.check),
              ),
            ),
            onChanged: (_) => setState(() {}),
            onSubmitted: (v) {
              final t = v.trim();
              _pick(t.isEmpty ? null : t);
            },
          ),
        ),
        ...() {
          final items = _filtered();
          if (items.isEmpty) {
            return [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Text(
                  hasOptions ? 'No matches' : 'No table options',
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
              ),
            ];
          }
          return [
            for (final item in items.take(40))
              MenuItemButton(
                onPressed: () => _pick(item),
                trailingIcon: pinned &&
                        widget.value!.toLowerCase() == item.toLowerCase()
                    ? Icon(Icons.check, color: scheme.primary, size: 18)
                    : null,
                child: Text(item),
              ),
          ];
        }(),
        const Divider(height: 1),
        MenuItemButton(
          onPressed: () => _pick(null),
          leadingIcon: const Icon(Icons.auto_mode_outlined, size: 18),
          child: const Text('Clear (Auto)'),
        ),
      ],
      child: field,
    );
  }
}

class _InlinePinField extends StatefulWidget {
  const _InlinePinField({
    required this.identity,
    required this.value,
    required this.hintText,
    required this.onChanged,
    this.labelText,
  });

  final String identity;
  final String? value;
  final String hintText;
  final String? labelText;
  final ValueChanged<String?> onChanged;

  @override
  State<_InlinePinField> createState() => _InlinePinFieldState();
}

class _InlinePinFieldState extends State<_InlinePinField> {
  final FocusNode _focusNode = FocusNode();
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value ?? '');
  }

  @override
  void didUpdateWidget(covariant _InlinePinField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.identity != widget.identity) {
      _controller.text = widget.value ?? '';
      return;
    }
    if (_focusNode.hasFocus) return;
    final next = widget.value ?? '';
    if (next != _controller.text) {
      _controller.text = next;
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final pinned = _controller.text.trim().isNotEmpty;
    return TextField(
      focusNode: _focusNode,
      controller: _controller,
      textCapitalization: TextCapitalization.sentences,
      decoration: InputDecoration(
        isDense: true,
        labelText: widget.labelText,
        hintText: widget.hintText,
        hintStyle: TextStyle(
          fontStyle: FontStyle.italic,
          color: scheme.onSurfaceVariant,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        filled: true,
        fillColor: pinned
            ? scheme.primaryContainer.withValues(alpha: 0.35)
            : scheme.surfaceContainerHighest.withValues(alpha: 0.35),
      ),
      onChanged: (raw) {
        final trimmed = raw.trim();
        widget.onChanged(trimmed.isEmpty ? null : raw.trimRight());
        setState(() {});
      },
    );
  }
}

class _PlanChip extends StatelessWidget {
  const _PlanChip({required this.plan});

  final GeneratorApplyPlanEntry plan;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = plan.willCreate
        ? (plan.missingNameFrom
            ? scheme.errorContainer
            : scheme.secondaryContainer)
        : scheme.surfaceContainerHighest;
    final fg = plan.willCreate
        ? (plan.missingNameFrom
            ? scheme.onErrorContainer
            : scheme.onSecondaryContainer)
        : scheme.onSurfaceVariant;
    final label = plan.willCreate
        ? (plan.missingNameFrom ? 'Name missing' : 'Will create')
        : 'Skipped';
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: fg,
                fontWeight: FontWeight.w600,
              ),
        ),
      ),
    );
  }
}

class _OrphanRecordCard extends StatelessWidget {
  const _OrphanRecordCard({
    required this.record,
    required this.plan,
    required this.onNameChanged,
  });

  final GeneratedRecord record;
  final GeneratorApplyPlanEntry? plan;
  final void Function(GeneratedRecord record, String nameFrom, String value)
      onNameChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final nameKey = plan?.nameFrom?.trim().isNotEmpty == true
        ? plan!.nameFrom!
        : GeneratorRunSession.preferredNameFieldKey(record);
    final nameValue = GeneratorRunSession.preferredRecordName(record);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: scheme.surfaceContainerHigh.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Text(
                    record.type,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  if (record.parentField != null) ...[
                    const SizedBox(width: 8),
                    Text(
                      'via ${record.parentField}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                  const Spacer(),
                  if (plan != null) _PlanChip(plan: plan!),
                ],
              ),
              const SizedBox(height: 8),
              _InlinePinField(
                identity: '${record.id}:$nameKey',
                value: nameValue,
                labelText: nameKey == 'name' ? 'Name' : 'Name ($nameKey)',
                hintText: 'Type a name',
                onChanged: (v) => onNameChanged(record, nameKey, v ?? ''),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScalarRow extends StatelessWidget {
  const _ScalarRow({
    required this.node,
    required this.pinned,
    required this.pulsing,
    required this.onClear,
    required this.onChanged,
    this.onRoll,
    this.preferText = false,
    this.plan,
  });

  final GeneratorScalarInput node;
  final String? pinned;
  final bool pulsing;
  final VoidCallback onClear;
  final ValueChanged<String?> onChanged;
  final VoidCallback? onRoll;
  final bool preferText;
  final GeneratorApplyPlanEntry? plan;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final auto = pinned == null;
    return Padding(
      padding: EdgeInsets.only(left: 12.0 * node.depth, bottom: 10),
      child: AnimatedScale(
        scale: pulsing ? 1.03 : 1,
        duration: const Duration(milliseconds: 160),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        node.label,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      if (node.helperText != null)
                        Text(
                          node.helperText!,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: _OptionMenuField(
                    identity: node.id,
                    value: pinned,
                    options: node.options,
                    onChanged: onChanged,
                    preferText: preferText,
                    hintText: preferText ? 'Type a name' : 'Auto',
                  ),
                ),
                if (onRoll != null)
                  IconButton(
                    tooltip: 'Roll',
                    onPressed: onRoll,
                    icon: const Icon(Icons.casino_outlined),
                  ),
                if (!auto)
                  IconButton(
                    tooltip: 'Clear',
                    onPressed: onClear,
                    icon: const Icon(Icons.close),
                  ),
              ],
            ),
            if (plan != null) ...[
              const SizedBox(height: 4),
              _PlanChip(plan: plan!),
            ],
          ],
        ),
      ),
    );
  }
}

class _GateBlock extends StatelessWidget {
  const _GateBlock({
    required this.node,
    required this.pinned,
    required this.pulsing,
    required this.showThen,
    required this.onClear,
    required this.onRoll,
    required this.onChanged,
    required this.thenChildren,
  });

  final GeneratorGateInput node;
  final String? pinned;
  final bool pulsing;
  final bool showThen;
  final VoidCallback onClear;
  final VoidCallback onRoll;
  final ValueChanged<String?> onChanged;
  final List<Widget> thenChildren;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(left: 12.0 * node.depth, bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ScalarRow(
            node: GeneratorScalarInput(
              id: node.id,
              label: node.label,
              tableId: node.tableId,
              options: node.options,
              kind: GeneratorScalarKind.roll,
              depth: 0,
              helperText: 'Proceeds when “${node.proceedValue}”',
            ),
            pinned: pinned,
            pulsing: pulsing,
            onClear: onClear,
            onRoll: onRoll,
            onChanged: onChanged,
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: showThen && thenChildren.isNotEmpty
                ? Padding(
                    padding: const EdgeInsets.only(left: 8, top: 4),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        border: Border(
                          left: BorderSide(
                            color: scheme.outlineVariant,
                            width: 2,
                          ),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.only(left: 12, top: 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: thenChildren,
                        ),
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _CollectionBlock extends StatelessWidget {
  const _CollectionBlock({
    required this.node,
    required this.count,
    required this.slots,
    required this.slotCount,
    required this.knownFloor,
    required this.pulse,
    required this.onCountChanged,
    required this.onClearCount,
    required this.onAddKnown,
    required this.onSlotClear,
    required this.onSlotRoll,
    required this.onSlotChanged,
    this.slotPlans = const [],
    this.onRollCount,
  });

  final GeneratorCollectionInput node;
  final int? count;
  final List<String?> slots;
  final int slotCount;
  final int knownFloor;
  final Map<String, bool> pulse;
  final List<GeneratorApplyPlanEntry?> slotPlans;
  final ValueChanged<int?> onCountChanged;
  final VoidCallback onClearCount;
  final VoidCallback? onRollCount;
  final VoidCallback onAddKnown;
  final ValueChanged<int> onSlotClear;
  final ValueChanged<int> onSlotRoll;
  final void Function(int index, String? value) onSlotChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final effectiveSlots = List<String?>.generate(
      slotCount,
      (i) => i < slots.length ? slots[i] : null,
    );
    final countLabel = count == null
        ? (knownFloor > 0 ? 'Auto (at least $knownFloor)' : 'Auto')
        : '$count';
    final keyHint = node.countSource?.keyField;

    return Padding(
      padding: EdgeInsets.only(left: 12.0 * node.depth, bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            node.label,
            style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            'Roll a count, set one manually, or add known '
            '${node.itemLabel.toLowerCase()}s — generation keeps at least '
            'as many as you listed.',
            style: textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          if (keyHint != null &&
              node.countSource?.kind == GeneratorScalarKind.lookup) ...[
            const SizedBox(height: 2),
            Text(
              'Auto count uses ${humanizeGeneratorFieldId(keyHint)}; '
              'roll count samples that lookup without changing it.',
              style: textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 10),
          AnimatedScale(
            scale: pulse['${node.id}#count'] == true ? 1.03 : 1,
            duration: const Duration(milliseconds: 160),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: scheme.outlineVariant),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                child: Row(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Text('Count', style: textTheme.labelLarge),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        countLabel,
                        style: textTheme.bodyMedium?.copyWith(
                          color: count == null
                              ? scheme.onSurfaceVariant
                              : scheme.onSurface,
                          fontStyle: count == null
                              ? FontStyle.italic
                              : FontStyle.normal,
                          fontWeight: count == null
                              ? FontWeight.w400
                              : FontWeight.w700,
                        ),
                      ),
                    ),
                    if (onRollCount != null)
                      IconButton(
                        tooltip: 'Roll count',
                        onPressed: onRollCount,
                        icon: const Icon(Icons.casino_outlined),
                      ),
                    IconButton(
                      tooltip: 'Decrease',
                      onPressed: () {
                        if (count == null) {
                          onCountChanged(knownFloor > 0 ? knownFloor : 1);
                          return;
                        }
                        final next = count! - 1;
                        onCountChanged(next < knownFloor ? knownFloor : next);
                      },
                      icon: const Icon(Icons.remove),
                    ),
                    IconButton(
                      tooltip: 'Increase',
                      onPressed: () =>
                          onCountChanged((count ?? knownFloor) + 1),
                      icon: const Icon(Icons.add),
                    ),
                    IconButton(
                      tooltip: 'Use auto count',
                      onPressed: count == null ? null : onClearCount,
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: Column(
              children: [
                for (var i = 0; i < effectiveSlots.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: AnimatedScale(
                      scale: pulse['${node.id}#$i'] == true ? 1.03 : 1,
                      duration: const Duration(milliseconds: 160),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              SizedBox(
                                width: 28,
                                child: Text(
                                  '${i + 1}',
                                  style: textTheme.labelLarge?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: _OptionMenuField(
                                  identity: '${node.id}#$i',
                                  value: effectiveSlots[i],
                                  options: node.options,
                                  onChanged: (v) => onSlotChanged(i, v),
                                  preferText: true,
                                  labelText: '${node.itemLabel} name',
                                  hintText: 'Name (Auto if empty)',
                                ),
                              ),
                              IconButton(
                                tooltip: 'Roll',
                                onPressed: () => onSlotRoll(i),
                                icon: const Icon(Icons.casino_outlined),
                              ),
                              if (effectiveSlots[i] != null)
                                IconButton(
                                  tooltip: 'Clear',
                                  onPressed: () => onSlotClear(i),
                                  icon: const Icon(Icons.close),
                                ),
                            ],
                          ),
                          if (i < slotPlans.length && slotPlans[i] != null)
                            Padding(
                              padding: const EdgeInsets.only(left: 28, top: 4),
                              child: _PlanChip(plan: slotPlans[i]!),
                            ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: onAddKnown,
              icon: const Icon(Icons.add, size: 18),
              label: Text('Add known ${node.itemLabel.toLowerCase()}'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ApplyPanel extends StatelessWidget {
  const _ApplyPanel({
    required this.planEntries,
    required this.warnings,
    required this.needsParent,
    required this.parentKind,
    required this.parentChoices,
    required this.loadingParents,
    required this.parentLoadError,
    required this.selectedParentId,
    required this.applying,
    required this.onParentChanged,
    required this.onCancel,
    required this.onConfirm,
  });

  final List<GeneratorApplyPlanEntry> planEntries;
  final List<String> warnings;
  final bool needsParent;
  final CatalogKind? parentKind;
  final List<CatalogItem>? parentChoices;
  final bool loadingParents;
  final String? parentLoadError;
  final int? selectedParentId;
  final bool applying;
  final ValueChanged<int?> onParentChanged;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final creates = [
      for (final e in planEntries)
        if (e.willCreate) e,
    ];
    final summary = <String, int>{};
    for (final e in creates) {
      final label = e.kind?.singularLabel ?? 'record';
      summary.update(label, (v) => v + 1, ifAbsent: () => 1);
    }
    final summaryText = summary.entries
        .map((e) => '${e.value} ${e.key}${e.value == 1 ? '' : 's'}')
        .join(', ');

    return Material(
      elevation: 8,
      color: scheme.surfaceContainerHigh,
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.42,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Apply to catalog',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: applying ? null : onCancel,
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  children: [
                    Text(
                      creates.isEmpty
                          ? 'Nothing to create.'
                          : 'Create $summaryText. Name conflicts will stop Apply.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    if (creates.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      for (final e in creates)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            children: [
                              Icon(
                                e.missingNameFrom
                                    ? Icons.warning_amber_rounded
                                    : Icons.check_circle_outline,
                                size: 16,
                                color: e.missingNameFrom
                                    ? scheme.error
                                    : scheme.primary,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  e.detail,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: e.missingNameFrom
                                            ? scheme.error
                                            : null,
                                      ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                    if (warnings.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      for (final w in warnings)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            w,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: scheme.error),
                          ),
                        ),
                    ],
                    if (needsParent && parentKind != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        'Parent ${parentKind!.singularLabel} (optional)',
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      const SizedBox(height: 6),
                      if (loadingParents)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Center(
                            child: SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        )
                      else if (parentLoadError != null)
                        Text(
                          parentLoadError!,
                          style: TextStyle(color: scheme.error),
                        )
                      else
                        DropdownMenu<int?>(
                          key: ValueKey(
                            'parent-${parentKind?.apiValue}-'
                            '${parentChoices?.length ?? 0}',
                          ),
                          initialSelection: selectedParentId,
                          expandedInsets: EdgeInsets.zero,
                          hintText: 'No parent',
                          onSelected: onParentChanged,
                          dropdownMenuEntries: [
                            const DropdownMenuEntry<int?>(
                              value: null,
                              label: 'No parent',
                            ),
                            for (final item
                                in parentChoices ?? const <CatalogItem>[])
                              DropdownMenuEntry<int?>(
                                value: item.id,
                                label: item.name,
                              ),
                          ],
                        ),
                    ],
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: Row(
                  children: [
                    TextButton(
                      onPressed: applying ? null : onCancel,
                      child: const Text('Cancel'),
                    ),
                    const Spacer(),
                    FilledButton.icon(
                      onPressed: applying || creates.isEmpty ? null : onConfirm,
                      icon: applying
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save_outlined, size: 18),
                      label: Text(applying ? 'Applying…' : 'Confirm apply'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
