import 'package:flutter/material.dart';

import '../../auth/data/auth_api.dart';
import '../../auth/state/auth_controller.dart';
import '../../settings/generators/data/generator_create_index.dart';
import '../../settings/generators/data/generator_model.dart';
import '../../settings/generators/ui/generator_run_sheet.dart';
import '../data/catalog_kind.dart';
import 'generator_create_picker.dart';

/// Expand FAB for catalog create: Manual form plus Generate picker.
///
/// When there are no matching generators, shows a plain + FAB.
/// When generators exist, expand shows only **Manual** and **Generate…**.
class CatalogCreateSpeedDial extends StatefulWidget {
  const CatalogCreateSpeedDial({
    super.key,
    required this.auth,
    required this.kind,
    required this.onManualCreate,
    this.onAfterGenerate,
    this.heroTagPrefix = 'catalog-create',
  });

  final AuthController auth;
  final CatalogKind kind;
  final VoidCallback onManualCreate;
  final VoidCallback? onAfterGenerate;
  final String heroTagPrefix;

  @override
  State<CatalogCreateSpeedDial> createState() => _CatalogCreateSpeedDialState();
}

class _CatalogCreateSpeedDialState extends State<CatalogCreateSpeedDial> {
  final _index = GeneratorCreateIndex();
  bool _open = false;
  bool _loading = true;
  List<GeneratorCreateEntry> _generators = const [];

  @override
  void initState() {
    super.initState();
    _reloadGenerators();
  }

  @override
  void didUpdateWidget(covariant CatalogCreateSpeedDial oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.kind != widget.kind) {
      _reloadGenerators();
    }
  }

  Future<void> _reloadGenerators() async {
    setState(() => _loading = true);
    try {
      final token = await widget.auth.requireAccessToken();
      if (token == null || !mounted) return;
      final entries = await _index.listForCreate(
        accessToken: token,
        kind: widget.kind,
      );
      if (!mounted) return;
      setState(() {
        _generators = entries;
        _loading = false;
      });
    } on AuthApiException {
      if (!mounted) return;
      setState(() {
        _generators = const [];
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _generators = const [];
        _loading = false;
      });
    }
  }

  void _toggle() {
    setState(() => _open = !_open);
  }

  void _close() {
    if (_open) setState(() => _open = false);
  }

  Future<void> _runGenerator(GeneratorRecord record) async {
    _close();
    try {
      final error = record.validateConfig();
      if (error != null) throw FormatException(error);
      if (!mounted) return;
      await showGeneratorRunWorkspace(
        context,
        record: record,
        auth: widget.auth,
      );
      widget.onAfterGenerate?.call();
      await _reloadGenerators();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Generate failed: $e')),
      );
    }
  }

  Future<void> _pickGenerator() async {
    _close();
    final selected = await showGeneratorCreatePicker(
      context,
      kind: widget.kind,
      generators: _generators,
    );
    if (selected == null || !mounted) return;
    await _runGenerator(selected.record);
  }

  void _onManual() {
    _close();
    widget.onManualCreate();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final useDial = !_loading && _generators.isNotEmpty;

    if (!useDial) {
      return FloatingActionButton(
        heroTag: '${widget.heroTagPrefix}-main',
        onPressed: widget.onManualCreate,
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        child: const Icon(Icons.add),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        AnimatedOpacity(
          opacity: _open ? 1 : 0,
          duration: const Duration(milliseconds: 180),
          child: IgnorePointer(
            ignoring: !_open,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _FabAction(
                  heroTag: '${widget.heroTagPrefix}-manual',
                  label: 'Manual',
                  icon: Icons.edit_outlined,
                  onPressed: _onManual,
                ),
                const SizedBox(height: 10),
                _FabAction(
                  heroTag: '${widget.heroTagPrefix}-generate',
                  label: 'Generate…',
                  icon: Icons.casino_outlined,
                  onPressed: _pickGenerator,
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
        FloatingActionButton(
          heroTag: '${widget.heroTagPrefix}-main',
          onPressed: _toggle,
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          child: AnimatedRotation(
            turns: _open ? 0.125 : 0,
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
    required this.heroTag,
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String heroTag;
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
          heroTag: heroTag,
          onPressed: onPressed,
          child: Icon(icon),
        ),
      ],
    );
  }
}
