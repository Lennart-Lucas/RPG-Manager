import 'package:flutter/material.dart';

import '../data/generator_input_spec.dart';
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

  @override
  void didUpdateWidget(covariant GeneratorTablesPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tablesDocument != widget.tablesDocument ||
        oldWidget.processDocument != widget.processDocument) {
      _graph = GeneratorTablesGraph.parse(
        tablesDocument: widget.tablesDocument,
        processDocument: widget.processDocument,
      );
    }
  }

  List<GeneratorTableViz> get _sortedTables {
    final tables = [..._graph.tables]..sort((a, b) => a.id.compareTo(b.id));
    return tables;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tables = _sortedTables;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (tables.isEmpty)
          Text(
            'No tables in this generator config yet.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          )
        else
          for (final table in tables) ...[
            _DnDRollTable(table: table),
            const SizedBox(height: 20),
          ],
      ],
    );
  }
}

class _DnDRollTable extends StatelessWidget {
  const _DnDRollTable({required this.table});

  final GeneratorTableViz table;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final title = humanizeGeneratorFieldId(table.id);
    final dice = table.diceLabel?.trim();
    final kindLine = switch (table.kind) {
      GeneratorTableKind.random => 'Random table',
      GeneratorTableKind.lookup => table.keyedBy == null
          ? 'Lookup table'
          : 'Lookup keyed by ${humanizeGeneratorFieldId(table.keyedBy!)}',
      GeneratorTableKind.process => 'Process',
      GeneratorTableKind.unknown => 'Unknown table',
    };

    final rollHeader = switch (table.kind) {
      GeneratorTableKind.random =>
        (dice != null && dice.isNotEmpty) ? dice : 'Roll',
      GeneratorTableKind.lookup => 'Key',
      _ => 'Roll',
    };
    final resultHeader = switch (table.kind) {
      GeneratorTableKind.lookup => 'Roll',
      _ => 'Result',
    };

    final rows = _rowsFor(table, scheme);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    kindLine,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
            if (dice != null &&
                dice.isNotEmpty &&
                table.kind == GeneratorTableKind.random) ...[
              const SizedBox(width: 12),
              Text(
                dice,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
            const SizedBox(width: 8),
            _KindChip(kind: table.kind),
          ],
        ),
        const SizedBox(height: 10),
        DecoratedBox(
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.85),
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(11),
            child: _RollGrid(
              rollHeader: rollHeader,
              resultHeader: resultHeader,
              rows: rows,
            ),
          ),
        ),
      ],
    );
  }

  List<_RollRowData> _rowsFor(GeneratorTableViz table, ColorScheme scheme) {
    switch (table.kind) {
      case GeneratorTableKind.random:
        if (table.bands.isEmpty) {
          return const [
            _RollRowData(left: '—', rightPlain: 'No entries', muted: true),
          ];
        }
        return [
          for (final band in table.bands)
            _RollRowData(
              left: band.rangeLabel,
              rightSpans: [
                TextSpan(text: band.value),
                if (band.subTable != null && band.subTable!.isNotEmpty)
                  TextSpan(
                    text: '  → ${band.subTable}',
                    style: TextStyle(color: scheme.primary),
                  ),
                if (band.modifiersLabel.isNotEmpty)
                  TextSpan(
                    text: '  (${band.modifiersLabel})',
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
              ],
            ),
        ];
      case GeneratorTableKind.lookup:
        if (table.lookupRows.isEmpty) {
          return const [
            _RollRowData(left: '—', rightPlain: 'No values', muted: true),
          ];
        }
        return [
          for (final row in table.lookupRows)
            _RollRowData(
              left: row.key,
              rightPlain: '→ ${row.diceLabel}',
              rightBold: true,
            ),
        ];
      case GeneratorTableKind.process:
      case GeneratorTableKind.unknown:
        return const [
          _RollRowData(
            left: '—',
            rightPlain: 'Unrecognized table type',
            muted: true,
          ),
        ];
    }
  }
}

class _RollRowData {
  const _RollRowData({
    required this.left,
    this.rightPlain,
    this.rightSpans,
    this.rightBold = false,
    this.muted = false,
  });

  final String left;
  final String? rightPlain;
  final List<InlineSpan>? rightSpans;
  final bool rightBold;
  final bool muted;
}

class _RollGrid extends StatelessWidget {
  const _RollGrid({
    required this.rollHeader,
    required this.resultHeader,
    required this.rows,
  });

  final String rollHeader;
  final String resultHeader;
  final List<_RollRowData> rows;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final borderColor = scheme.outlineVariant.withValues(alpha: 0.85);
    final headerBg = scheme.surfaceContainerHigh;
    final rowBase = scheme.surfaceContainerLowest;
    final rowEvenBg = Color.alphaBlend(
      scheme.onSurface.withValues(alpha: 0.06),
      rowBase,
    );
    final rowOddBg = Color.alphaBlend(
      scheme.onSurface.withValues(alpha: 0.14),
      rowBase,
    );
    final headerStyle = textTheme.labelLarge?.copyWith(
      fontWeight: FontWeight.w700,
    );
    final bodyStyle = textTheme.bodyMedium;

    Widget cell({
      required Widget child,
      required Color bg,
      bool rollCol = false,
    }) {
      return ColoredBox(
        color: bg,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: rollCol ? 10 : 12,
            vertical: 8,
          ),
          child: child,
        ),
      );
    }

    return Table(
      border: TableBorder(
        horizontalInside: BorderSide(color: borderColor, width: 1),
        verticalInside: BorderSide(color: borderColor, width: 1),
      ),
      columnWidths: const {
        0: IntrinsicColumnWidth(),
        1: FlexColumnWidth(),
      },
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        TableRow(
          children: [
            cell(
              bg: headerBg,
              rollCol: true,
              child: Text(rollHeader, style: headerStyle),
            ),
            cell(
              bg: headerBg,
              child: Text(resultHeader, style: headerStyle),
            ),
          ],
        ),
        for (var i = 0; i < rows.length; i++)
          TableRow(
            children: [
              cell(
                bg: i.isEven ? rowEvenBg : rowOddBg,
                rollCol: true,
                child: Text(
                  rows[i].left,
                  style: bodyStyle?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                    fontStyle:
                        rows[i].muted ? FontStyle.italic : FontStyle.normal,
                  ),
                ),
              ),
              cell(
                bg: i.isEven ? rowEvenBg : rowOddBg,
                child: rows[i].rightSpans != null
                    ? Text.rich(
                        TextSpan(
                          style: bodyStyle?.copyWith(
                            fontStyle: rows[i].muted
                                ? FontStyle.italic
                                : FontStyle.normal,
                            color: rows[i].muted
                                ? scheme.onSurfaceVariant
                                : null,
                          ),
                          children: rows[i].rightSpans,
                        ),
                      )
                    : Text(
                        rows[i].rightPlain ?? '',
                        style: bodyStyle?.copyWith(
                          fontWeight: rows[i].rightBold
                              ? FontWeight.w600
                              : FontWeight.w400,
                          fontStyle: rows[i].muted
                              ? FontStyle.italic
                              : FontStyle.normal,
                          color: rows[i].muted
                              ? scheme.onSurfaceVariant
                              : null,
                        ),
                      ),
              ),
            ],
          ),
      ],
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
