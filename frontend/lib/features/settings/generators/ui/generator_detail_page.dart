import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:random_table_engine/generation_engine.dart';

import '../../../auth/data/auth_api.dart';
import '../../../auth/state/auth_controller.dart';
import '../../../catalog/data/catalog_api.dart';
import '../../../catalog/data/catalog_kind.dart';
import '../../../catalog/data/catalog_models.dart';
import '../../../dm_tools/resources/resources_icons.dart';
import '../data/generator_model.dart';
import 'generator_form_sheet.dart';
import 'generator_tables_panel.dart';

class GeneratorDetailPage extends StatefulWidget {
  const GeneratorDetailPage({
    super.key,
    required this.auth,
    required this.item,
  });

  final AuthController auth;
  final CatalogItem item;

  @override
  State<GeneratorDetailPage> createState() => _GeneratorDetailPageState();
}

class _GeneratorDetailPageState extends State<GeneratorDetailPage> {
  final _api = CatalogApi();
  late CatalogItem _item = widget.item;

  GeneratorRecord get _record => GeneratorRecord.fromCatalogPayload(
        name: _item.name,
        payload: _item.payload,
      );

  Future<String?> _token() => widget.auth.requireAccessToken();

  Future<void> _edit() async {
    try {
      final token = await _token();
      if (token == null || !mounted) return;
      final draft = await showGeneratorFormSheet(context, initial: _record);
      if (draft == null || !mounted) return;
      final updated = await _api.update(
        accessToken: token,
        kind: CatalogKind.generators,
        itemId: _item.id,
        name: draft.name,
        payload: draft.toJson(),
      );
      setState(() => _item = updated);
    } on AuthApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not update generator')),
      );
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete generator?'),
        content: Text('Delete “${_item.name}”? This cannot be undone.'),
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
    if (confirmed != true || !mounted) return;
    try {
      final token = await _token();
      if (token == null) return;
      await _api.delete(
        accessToken: token,
        kind: CatalogKind.generators,
        itemId: _item.id,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on AuthApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not delete generator')),
      );
    }
  }

  Future<void> _runPreview() async {
    try {
      // Validate early so failures surface as a snackbar, not an empty sheet.
      final error = _record.validateConfig();
      if (error != null) throw FormatException(error);
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (context) => _GeneratorPreviewSheet(record: _record),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Preview failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final record = _record;
    final tableCount = (record.tablesDocument['tables'] is Map)
        ? (record.tablesDocument['tables'] as Map).length
        : 0;
    final stepCount = (record.processDocument['steps'] is List)
        ? (record.processDocument['steps'] as List).length
        : 0;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _item.name.trim().isEmpty ? 'Generator' : _item.name,
        ),
        actions: [
          IconButton(
            tooltip: 'Run preview',
            icon: const Icon(Icons.play_arrow_outlined),
            onPressed: _runPreview,
          ),
          IconButton(
            tooltip: 'Edit',
            icon: const Icon(Icons.edit_outlined),
            onPressed: _edit,
          ),
          IconButton(
            tooltip: 'Delete',
            icon: const Icon(Icons.delete_outline),
            onPressed: _delete,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer.withValues(alpha: 0.88),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  generatorPageIcon,
                  color: scheme.onPrimaryContainer,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _item.name,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Record type: ${record.recordTypeLabel}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: scheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            '$tableCount tables · $stepCount process steps',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Run preview rolls the tables and shows generated records without '
            'saving anything to the catalog.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _runPreview,
            icon: const Icon(Icons.play_arrow),
            label: const Text('Run preview'),
          ),
          const SizedBox(height: 32),
          GeneratorTablesPanel(
            tablesDocument: record.tablesDocument,
            processDocument: record.processDocument,
          ),
        ],
      ),
    );
  }
}

class _GeneratorPreviewSheet extends StatefulWidget {
  const _GeneratorPreviewSheet({required this.record});

  final GeneratorRecord record;

  @override
  State<_GeneratorPreviewSheet> createState() => _GeneratorPreviewSheetState();
}

class _GeneratorPreviewSheetState extends State<_GeneratorPreviewSheet> {
  late List<GeneratedRecord> _records = widget.record.runPreview();
  String? _error;

  void _rerun() {
    setState(() {
      try {
        _records = widget.record.runPreview();
        _error = null;
      } catch (e) {
        _error = '$e';
      }
    });
  }

  Map<String, int> get _typeCounts {
    final counts = <String, int>{};
    for (final r in _records) {
      counts.update(r.type, (v) => v + 1, ifAbsent: () => 1);
    }
    return counts;
  }

  List<GeneratedRecord> _childrenOf(String parentId) {
    return _records.where((r) => r.parentId == parentId).toList();
  }

  GeneratedRecord? get _root {
    if (_records.isEmpty) return null;
    for (final r in _records) {
      if (r.parentId == null) return r;
    }
    return _records.first;
  }

  static String _formatValue(Object? value) {
    if (value == null) return '—';
    if (value is String) return value;
    if (value is num || value is bool) return '$value';
    if (value is List) {
      if (value.isEmpty) return '(empty)';
      return value.map(_formatValue).join(', ');
    }
    if (value is Map) {
      try {
        return const JsonEncoder.withIndent('  ').convert(value);
      } catch (_) {
        return value.toString();
      }
    }
    return value.toString();
  }

  int get _stepCount {
    final steps = widget.record.processDocument['steps'];
    return steps is List ? steps.length : 0;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final height = MediaQuery.sizeOf(context).height * 0.85;
    final root = _root;
    final typeSummary = _typeCounts.entries
        .map((e) => '${e.value} ${e.key}')
        .join(' · ');

    return SizedBox(
      height: height,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 16, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Preview: ${widget.record.name}',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _error != null
                            ? 'Failed'
                            : '${_records.length} record${_records.length == 1 ? '' : 's'}'
                                '${typeSummary.isEmpty ? '' : ' · $typeSummary'}'
                                ' · not saved',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: _rerun,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Run again'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: scheme.error),
                      ),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                    children: [
                      if (_stepCount == 0)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Material(
                            color: scheme.secondaryContainer
                                .withValues(alpha: 0.55),
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Text(
                                'This generator’s process has no steps, so the '
                                'preview only creates an empty root record. '
                                'Add process steps (roll, lookup, rollMany, …) '
                                'to fill in fields and child records.',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      color: scheme.onSecondaryContainer,
                                    ),
                              ),
                            ),
                          ),
                        ),
                      if (root != null)
                        _PreviewRecordNode(
                          record: root,
                          childrenOf: _childrenOf,
                          formatValue: _formatValue,
                          depth: 0,
                        )
                      else
                        const Padding(
                          padding: EdgeInsets.all(24),
                          child: Text('No records produced.'),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _PreviewRecordNode extends StatelessWidget {
  const _PreviewRecordNode({
    required this.record,
    required this.childrenOf,
    required this.formatValue,
    required this.depth,
  });

  final GeneratedRecord record;
  final List<GeneratedRecord> Function(String parentId) childrenOf;
  final String Function(Object? value) formatValue;
  final int depth;

  static String _signed(int value) => value >= 0 ? '+$value' : '$value';

  static String? _formatRollMeta(Object? raw) {
    if (raw is List) {
      return raw.map(_formatRollMeta).whereType<String>().join(' · ');
    }
    if (raw is! Map) return null;
    final roll = raw['roll'];
    final modifier = raw['modifier'] ?? 0;
    final total = raw['total'];
    final clamped = raw['clamped'];
    if (roll == null && total == null) return null;
    final modInt = modifier is int
        ? modifier
        : (modifier is num ? modifier.toInt() : 0);
    final parts = <String>[
      if (roll != null) 'rolled $roll',
      'mod ${_signed(modInt)}',
      if (total != null) 'total $total',
      if (clamped != null && clamped != total) 'clamped $clamped',
    ];
    final produced = raw['producedModifiers'];
    if (produced is Map && produced.isNotEmpty) {
      final mods = produced.entries
          .map((e) {
            final v = e.value;
            final n = v is int ? v : (v is num ? v.toInt() : 0);
            return '${e.key}${_signed(n)}';
          })
          .join(', ');
      parts.add('→ $mods');
    }
    final detail = raw['detail'];
    if (detail is Map) {
      final nested = _formatRollMeta(detail);
      if (nested != null) parts.add('detail ($nested)');
    }
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final children = childrenOf(record.id);
    final byField = <String?, List<GeneratedRecord>>{};
    for (final child in children) {
      byField.putIfAbsent(child.parentField, () => []).add(child);
    }
    final rolls = record.rollsMeta ?? const <String, dynamic>{};
    final modifiers = record.modifiersMeta;
    final fieldEntries = record.fields.entries
        .where(
          (e) =>
              e.key != GeneratedRecord.rollsField &&
              e.key != GeneratedRecord.modifiersField,
        )
        .toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return Padding(
      padding: EdgeInsets.only(left: depth == 0 ? 0 : 12, bottom: 10),
      child: Material(
        color: depth == 0
            ? scheme.surfaceContainerHighest.withValues(alpha: 0.55)
            : scheme.surfaceContainerHigh.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      record.type,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: scheme.onPrimaryContainer,
                            fontWeight: FontWeight.w600,
                          ),
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
                ],
              ),
              if (modifiers != null && modifiers.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  'Modifiers',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: scheme.primary,
                      ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    for (final e in (modifiers.entries.toList()
                      ..sort((a, b) => a.key.compareTo(b.key))))
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: scheme.secondaryContainer.withValues(
                            alpha: 0.7,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${e.key} ${_signed(e.value)}',
                          style: Theme.of(context)
                              .textTheme
                              .labelMedium
                              ?.copyWith(
                                color: scheme.onSecondaryContainer,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ),
                  ],
                ),
              ],
              if (fieldEntries.isEmpty && children.isEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  'No fields',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontStyle: FontStyle.italic,
                      ),
                ),
              ],
              if (fieldEntries.isNotEmpty) ...[
                const SizedBox(height: 10),
                for (final e in fieldEntries)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 140,
                          child: Text(
                            e.key,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SelectableText(
                                formatValue(e.value),
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                              if (_formatRollMeta(rolls[e.key])
                                  case final rollLine?) ...[
                                const SizedBox(height: 2),
                                Text(
                                  rollLine,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: scheme.onSurfaceVariant,
                                      ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                // Roll-only metas (e.g. failed gates without a field value)
                for (final e in rolls.entries)
                  if (!fieldEntries.any((f) => f.key == e.key))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 140,
                            child: Text(
                              e.key,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              _formatRollMeta(e.value) ?? formatValue(e.value),
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),
              ],
              for (final group in byField.entries) ...[
                const SizedBox(height: 8),
                Text(
                  '${group.key ?? 'children'} (${group.value.length})',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: scheme.primary,
                      ),
                ),
                const SizedBox(height: 6),
                for (final child in group.value)
                  _PreviewRecordNode(
                    record: child,
                    childrenOf: childrenOf,
                    formatValue: formatValue,
                    depth: depth + 1,
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
