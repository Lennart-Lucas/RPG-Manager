import 'package:flutter/material.dart';

import '../../../auth/data/auth_api.dart';
import '../../../auth/state/auth_controller.dart';
import '../../../catalog/data/catalog_api.dart';
import '../../../catalog/data/catalog_kind.dart';
import '../../../catalog/data/catalog_models.dart';
import '../../../dm_tools/resources/resources_icons.dart';
import '../data/generator_model.dart';
import 'generator_form_sheet.dart';
import 'generator_run_sheet.dart';
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
      await showGeneratorRunWorkspace(
        context,
        record: _record,
        auth: widget.auth,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Generate failed: $e')),
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
    final bindingCount = record.recordMappingOrEmpty.bindings.length;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _item.name.trim().isEmpty ? 'Generator' : _item.name,
        ),
        actions: [
          IconButton(
            tooltip: 'Generate',
            icon: const Icon(Icons.play_arrow_outlined),
            onPressed: _runPreview,
          ),
          if (widget.auth.canMutateCatalog) ...[
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
                    if (record.appliesTo != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Create as: ${record.appliesTo!.displayLabel}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            '$tableCount tables · $stepCount process steps · '
            '$bindingCount mapping binding${bindingCount == 1 ? '' : 's'}',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 24),
          GeneratorTablesPanel(
            tablesDocument: record.tablesDocument,
            processDocument: record.processDocument,
          ),
        ],
      ),
    );
  }
}
