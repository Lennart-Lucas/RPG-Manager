import 'package:flutter/material.dart';

import '../../settings/generators/data/generator_create_index.dart';
import '../data/catalog_kind.dart';

/// Searchable picker for generators offered on a catalog create surface.
Future<GeneratorCreateEntry?> showGeneratorCreatePicker(
  BuildContext context, {
  required CatalogKind kind,
  required List<GeneratorCreateEntry> generators,
}) {
  final wide = MediaQuery.sizeOf(context).width >= 720;
  if (wide) {
    return showDialog<GeneratorCreateEntry>(
      context: context,
      builder: (context) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440, maxHeight: 420),
          child: _GeneratorCreatePickerBody(
            kind: kind,
            generators: generators,
          ),
        ),
      ),
    );
  }
  return showModalBottomSheet<GeneratorCreateEntry>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) {
      final height = MediaQuery.sizeOf(context).height * 0.7;
      return SafeArea(
        child: SizedBox(
          height: height,
          child: _GeneratorCreatePickerBody(
            kind: kind,
            generators: generators,
          ),
        ),
      );
    },
  );
}

class _GeneratorCreatePickerBody extends StatefulWidget {
  const _GeneratorCreatePickerBody({
    required this.kind,
    required this.generators,
  });

  final CatalogKind kind;
  final List<GeneratorCreateEntry> generators;

  @override
  State<_GeneratorCreatePickerBody> createState() =>
      _GeneratorCreatePickerBodyState();
}

class _GeneratorCreatePickerBodyState extends State<_GeneratorCreatePickerBody> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<GeneratorCreateEntry> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return widget.generators;
    return [
      for (final entry in widget.generators)
        if (entry.name.toLowerCase().contains(q) ||
            entry.subtitle.toLowerCase().contains(q))
          entry,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Generate ${widget.kind.singularLabel}',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              IconButton(
                tooltip: 'Close',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: TextField(
            controller: _searchController,
            autofocus: MediaQuery.sizeOf(context).width >= 720,
            decoration: InputDecoration(
              hintText: 'Search generators',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear',
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _query = '');
                      },
                      icon: const Icon(Icons.clear),
                    ),
              border: const OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (value) => setState(() => _query = value),
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Text(
                    'No matching generators',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                  ),
                )
              : ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final entry = filtered[index];
                    return ListTile(
                      leading: const Icon(Icons.casino_outlined),
                      title: Text(entry.name),
                      subtitle: Text(entry.subtitle),
                      onTap: () => Navigator.pop(context, entry),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
