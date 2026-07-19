import 'package:flutter/material.dart';

import '../../../auth/data/auth_api.dart';
import '../../../auth/state/auth_controller.dart';
import '../../../catalog/data/catalog_api.dart';
import '../../../catalog/data/catalog_kind.dart';
import '../../../catalog/data/catalog_models.dart';
import '../../../dm_tools/resources/resources_icons.dart';
import '../data/generator_model.dart';
import 'generator_detail_page.dart';
import 'generator_form_sheet.dart';

class GeneratorsBody extends StatefulWidget {
  const GeneratorsBody({super.key, required this.auth});

  final AuthController auth;

  @override
  State<GeneratorsBody> createState() => _GeneratorsBodyState();
}

class _GeneratorsBodyState extends State<GeneratorsBody> {
  final _api = CatalogApi();

  bool _loading = true;
  String? _error;
  List<CatalogItem> _items = const [];

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<String?> _token() => widget.auth.requireAccessToken();

  GeneratorRecord _fromItem(CatalogItem item) {
    return GeneratorRecord.fromCatalogPayload(
      name: item.name,
      payload: item.payload,
    );
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
      final items = await _api.list(token, CatalogKind.generators);
      if (!mounted) return;
      setState(() {
        _items = items;
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
        _error = 'Could not load generators';
        _loading = false;
      });
    }
  }

  Future<void> _create() async {
    final draft = await showGeneratorFormSheet(context);
    if (draft == null || !mounted) return;
    try {
      final token = await _token();
      if (token == null) return;
      await _api.create(
        accessToken: token,
        kind: CatalogKind.generators,
        name: draft.name,
        payload: draft.toJson(),
      );
      await _reload();
    } on AuthApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not create generator')),
      );
    }
  }

  Future<void> _openDetail(CatalogItem item) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => GeneratorDetailPage(
          auth: widget.auth,
          item: item,
        ),
      ),
    );
    if (changed == true && mounted) {
      await _reload();
    } else if (mounted) {
      await _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(onPressed: _reload, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    return Stack(
      children: [
        if (_items.isEmpty)
          Center(
            child: Text(
              'No generators yet.\nAdd one to store a tables + process config.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
          )
        else
          ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
            itemCount: _items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 4),
            itemBuilder: (context, index) {
              final item = _items[index];
              final record = _fromItem(item);
              return ListTile(
                leading: Icon(generatorPageIcon, color: scheme.primary),
                title: Text(item.name),
                subtitle: Text(
                  'Type: ${record.recordTypeLabel}',
                ),
                onTap: () => _openDetail(item),
              );
            },
          ),
        Positioned(
          right: 20,
          bottom: 20,
          child: FloatingActionButton(
            onPressed: _create,
            tooltip: 'New generator',
            child: const Icon(Icons.add),
          ),
        ),
      ],
    );
  }
}
