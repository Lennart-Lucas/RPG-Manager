import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/generator_tables_viz.dart';

class GeneratorTablesPanel extends StatefulWidget {
  const GeneratorTablesPanel({
    super.key,
    required this.tablesDocument,
    required this.processDocument,
  });

  final Map<String, dynamic> tablesDocument;
  final Map<String, dynamic> processDocument;

  @override
  State<GeneratorTablesPanel> createState() => _GeneratorTablesPanelState();
}

class _GeneratorTablesPanelState extends State<GeneratorTablesPanel> {
  late GeneratorTablesGraph _graph = GeneratorTablesGraph.parse(
    tablesDocument: widget.tablesDocument,
    processDocument: widget.processDocument,
  );

  final Map<String, GlobalKey> _cardKeys = {};
  final Map<String, ExpansibleController> _controllers = {};
  String? _focusedId;

  @override
  void didUpdateWidget(covariant GeneratorTablesPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tablesDocument != widget.tablesDocument ||
        oldWidget.processDocument != widget.processDocument) {
      _graph = GeneratorTablesGraph.parse(
        tablesDocument: widget.tablesDocument,
        processDocument: widget.processDocument,
      );
      _cardKeys.clear();
      _controllers.clear();
      _focusedId = null;
    }
  }

  GlobalKey _keyFor(String id) =>
      _cardKeys.putIfAbsent(id, GlobalKey.new);

  ExpansibleController _controllerFor(String id) =>
      _controllers.putIfAbsent(id, ExpansibleController.new);

  Future<void> _focusTable(String id) async {
    if (id == GeneratorTablesGraph.processNodeId) return;
    setState(() => _focusedId = id);
    final controller = _controllerFor(id);
    if (!controller.isExpanded) {
      controller.expand();
    }
    final key = _keyFor(id);
    final ctx = key.currentContext;
    if (ctx != null) {
      await Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
        alignment: 0.1,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Tables',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        if (_graph.isEmpty)
          Text(
            'No tables in this generator config yet.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          )
        else ...[
          Text(
            'Tap a node to open its table. Pinch or drag to explore the graph.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 12),
          _TablesGraphView(
            graph: _graph,
            focusedId: _focusedId,
            onNodeTap: _focusTable,
          ),
          const SizedBox(height: 20),
          Text(
            'Table contents',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          for (final table in _graph.tables)
            KeyedSubtree(
              key: _keyFor(table.id),
              child: _TableCard(
                table: table,
                controller: _controllerFor(table.id),
                highlighted: _focusedId == table.id,
              ),
            ),
        ],
      ],
    );
  }
}

class _TablesGraphView extends StatelessWidget {
  const _TablesGraphView({
    required this.graph,
    required this.onNodeTap,
    this.focusedId,
  });

  final GeneratorTablesGraph graph;
  final String? focusedId;
  final ValueChanged<String> onNodeTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const height = 260.0;

    return Material(
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: height,
        child: InteractiveViewer(
          boundaryMargin: const EdgeInsets.all(48),
          minScale: 0.55,
          maxScale: 2.5,
          child: CustomPaint(
            painter: _GraphPainter(
              graph: graph,
              focusedId: focusedId,
              scheme: scheme,
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final layout = _GraphLayout.compute(
                  graph: graph,
                  size: Size(constraints.maxWidth, height),
                );
                final kindById = {
                  for (final t in graph.tables) t.id: t.kind,
                };
                return SizedBox(
                  width: constraints.maxWidth,
                  height: height,
                  child: Stack(
                    children: [
                      for (final entry in layout.positions.entries)
                        Positioned(
                          left: entry.value.dx - layout.nodeWidth / 2,
                          top: entry.value.dy - layout.nodeHeight / 2,
                          width: layout.nodeWidth,
                          height: layout.nodeHeight,
                          child: _GraphNodeChip(
                            label: entry.key ==
                                    GeneratorTablesGraph.processNodeId
                                ? 'Process'
                                : entry.key,
                            kind: entry.key ==
                                    GeneratorTablesGraph.processNodeId
                                ? GeneratorTableKind.process
                                : kindById[entry.key] ??
                                    GeneratorTableKind.unknown,
                            selected: focusedId == entry.key,
                            onTap: () => onNodeTap(entry.key),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _GraphNodeChip extends StatelessWidget {
  const _GraphNodeChip({
    required this.label,
    required this.kind,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final GeneratorTableKind kind;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (bg, fg) = switch (kind) {
      GeneratorTableKind.lookup => (
          scheme.tertiaryContainer,
          scheme.onTertiaryContainer,
        ),
      GeneratorTableKind.process => (
          scheme.secondaryContainer,
          scheme.onSecondaryContainer,
        ),
      GeneratorTableKind.random => (
          scheme.primaryContainer,
          scheme.onPrimaryContainer,
        ),
      GeneratorTableKind.unknown => (
          scheme.surfaceContainerHighest,
          scheme.onSurface,
        ),
    };

    return Material(
      color: bg,
      elevation: selected ? 3 : 0,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: selected
                ? Border.all(color: scheme.primary, width: 2)
                : null,
          ),
          child: Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: fg,
                  fontWeight: FontWeight.w600,
                  height: 1.1,
                ),
          ),
        ),
      ),
    );
  }
}

class _GraphLayout {
  const _GraphLayout({
    required this.positions,
    required this.nodeWidth,
    required this.nodeHeight,
  });

  final Map<String, Offset> positions;
  final double nodeWidth;
  final double nodeHeight;

  static _GraphLayout compute({
    required GeneratorTablesGraph graph,
    required Size size,
  }) {
    const nodeWidth = 88.0;
    const nodeHeight = 36.0;
    final center = Offset(size.width / 2, size.height / 2);
    final positions = <String, Offset>{};

    if (graph.hasProcessHub) {
      positions[GeneratorTablesGraph.processNodeId] = center;
    }

    final ids = graph.tables.map((t) => t.id).toList();
    if (ids.isEmpty) {
      return _GraphLayout(
        positions: positions,
        nodeWidth: nodeWidth,
        nodeHeight: nodeHeight,
      );
    }

    final radius = math.min(size.width, size.height) * 0.36;
    for (var i = 0; i < ids.length; i++) {
      final angle = -math.pi / 2 + (2 * math.pi * i / ids.length);
      positions[ids[i]] = Offset(
        center.dx + radius * math.cos(angle),
        center.dy + radius * math.sin(angle),
      );
    }

    return _GraphLayout(
      positions: positions,
      nodeWidth: nodeWidth,
      nodeHeight: nodeHeight,
    );
  }
}

class _GraphPainter extends CustomPainter {
  _GraphPainter({
    required this.graph,
    required this.scheme,
    this.focusedId,
  });

  final GeneratorTablesGraph graph;
  final ColorScheme scheme;
  final String? focusedId;

  @override
  void paint(Canvas canvas, Size size) {
    final layout = _GraphLayout.compute(graph: graph, size: size);
    final paint = Paint()
      ..color = scheme.outlineVariant
      ..strokeWidth = 1.25
      ..style = PaintingStyle.stroke;

    final labelStyle = TextStyle(
      color: scheme.onSurfaceVariant.withValues(alpha: 0.85),
      fontSize: 9,
      fontWeight: FontWeight.w500,
    );

    for (final edge in graph.edges) {
      final from = layout.positions[edge.fromId];
      final to = layout.positions[edge.toId];
      if (from == null || to == null) continue;

      final highlighted = focusedId == edge.fromId || focusedId == edge.toId;
      paint.color = highlighted
          ? scheme.primary.withValues(alpha: 0.7)
          : scheme.outlineVariant;
      paint.strokeWidth = highlighted ? 1.8 : 1.25;

      canvas.drawLine(from, to, paint);

      final mid = Offset((from.dx + to.dx) / 2, (from.dy + to.dy) / 2);
      final tp = TextPainter(
        text: TextSpan(text: edge.label, style: labelStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, mid - Offset(tp.width / 2, tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant _GraphPainter oldDelegate) {
    return oldDelegate.graph != graph ||
        oldDelegate.focusedId != focusedId ||
        oldDelegate.scheme != scheme;
  }
}

class _TableCard extends StatelessWidget {
  const _TableCard({
    required this.table,
    required this.controller,
    required this.highlighted,
  });

  final GeneratorTableViz table;
  final ExpansibleController controller;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final subtitle = switch (table.kind) {
      GeneratorTableKind.random => table.diceLabel ?? 'random',
      GeneratorTableKind.lookup =>
        table.keyedBy == null ? 'lookup' : 'keyed by ${table.keyedBy}',
      GeneratorTableKind.process => 'process',
      GeneratorTableKind.unknown => 'unknown',
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: highlighted
            ? scheme.primaryContainer.withValues(alpha: 0.35)
            : scheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        child: ExpansionTile(
          controller: controller,
          shape: const Border(),
          collapsedShape: const Border(),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  table.id,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              _KindChip(kind: table.kind),
            ],
          ),
          subtitle: Text(subtitle),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          children: [
            if (table.kind == GeneratorTableKind.random) ...[
              if (table.bands.isEmpty)
                Text(
                  'No entries',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontStyle: FontStyle.italic,
                      ),
                )
              else
                for (final band in table.bands) _BandRow(band: band),
            ] else if (table.kind == GeneratorTableKind.lookup) ...[
              if (table.lookupRows.isEmpty)
                Text(
                  'No values',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontStyle: FontStyle.italic,
                      ),
                )
              else
                for (final row in table.lookupRows) _LookupRowView(row: row),
            ] else
              Text(
                'Unrecognized table type',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
              ),
          ],
        ),
      ),
    );
  }
}

class _KindChip extends StatelessWidget {
  const _KindChip({required this.kind});

  final GeneratorTableKind kind;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final label = switch (kind) {
      GeneratorTableKind.random => 'random',
      GeneratorTableKind.lookup => 'lookup',
      GeneratorTableKind.process => 'process',
      GeneratorTableKind.unknown => '?',
    };
    final (bg, fg) = switch (kind) {
      GeneratorTableKind.lookup => (
          scheme.tertiaryContainer,
          scheme.onTertiaryContainer,
        ),
      GeneratorTableKind.random => (
          scheme.primaryContainer,
          scheme.onPrimaryContainer,
        ),
      _ => (scheme.surfaceContainerHighest, scheme.onSurfaceVariant),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: fg,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class _BandRow extends StatelessWidget {
  const _BandRow({required this.band});

  final GeneratorTableBand band;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final mods = band.modifiersLabel;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 56,
            child: Text(
              band.rangeLabel,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: band.value),
                  if (band.subTable != null && band.subTable!.isNotEmpty)
                    TextSpan(
                      text: '  → ${band.subTable}',
                      style: TextStyle(color: scheme.primary),
                    ),
                  if (mods.isNotEmpty)
                    TextSpan(
                      text: '  ($mods)',
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                ],
              ),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _LookupRowView extends StatelessWidget {
  const _LookupRowView({required this.row});

  final GeneratorLookupRow row;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              row.key,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
          ),
          Text(
            '→ ${row.diceLabel}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}
