import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../core/theme/app_theme.dart';
import 'card_export_theme.dart';

/// A4 card grid: how many cards per row and column on one sheet.
enum PdfGridPreset {
  threeByThree(3, 3),
  twoByThree(2, 3),
  twoByTwo(2, 2);

  const PdfGridPreset(this.cardsPerRow, this.cardsPerColumn);
  final int cardsPerRow;
  final int cardsPerColumn;

  String get label => switch (this) {
        PdfGridPreset.threeByThree => '3 × 3',
        PdfGridPreset.twoByThree => '2 × 3',
        PdfGridPreset.twoByTwo => '2 × 2',
      };
}

/// Bottom sheet: preview, theme, grid, margins, generate.
class CardPdfExportSheet extends StatefulWidget {
  const CardPdfExportSheet({
    super.key,
    required this.sheetTitle,
    required this.hasSelection,
    required this.composePdf,
    required this.onGenerate,
    this.previewHeight = 600,
  });

  final String sheetTitle;
  final bool hasSelection;
  final Future<Uint8List?> Function({
    required CardExportThemeSelection cardExportTheme,
    required int cardsPerRow,
    required int cardsPerColumn,
    required double pageMargin,
    required double cardGap,
  }) composePdf;
  final void Function({
    required CardExportThemeSelection cardExportTheme,
    required int cardsPerRow,
    required int cardsPerColumn,
    required double pageMargin,
    required double cardGap,
  }) onGenerate;

  /// Height of the preview viewport (first PDF page).
  final double previewHeight;

  @override
  State<CardPdfExportSheet> createState() => _CardPdfExportSheetState();
}

class _CardPdfExportSheetState extends State<CardPdfExportSheet> {
  CardExportThemeSelection cardExportTheme = const CardExportMatchApp();
  PdfGridPreset grid = PdfGridPreset.threeByThree;
  double pageMargin = 16;
  double cardGap = 8;
  int _previewToken = 0;
  Future<Uint8List?>? _previewFuture;
  Timer? _previewDebounce;

  @override
  void initState() {
    super.initState();
    if (widget.hasSelection) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _reloadPreview(immediate: true);
      });
    }
  }

  @override
  void dispose() {
    _previewDebounce?.cancel();
    super.dispose();
  }

  void _reloadPreview({bool immediate = false}) {
    _previewDebounce?.cancel();
    if (!widget.hasSelection) {
      setState(() {
        _previewFuture = null;
      });
      return;
    }

    void start() {
      if (!mounted) return;
      final token = ++_previewToken;
      final future = widget.composePdf(
        cardExportTheme: cardExportTheme,
        cardsPerRow: grid.cardsPerRow,
        cardsPerColumn: grid.cardsPerColumn,
        pageMargin: pageMargin,
        cardGap: cardGap,
      );
      setState(() {
        _previewFuture = future.then((bytes) {
          // Drop stale results if a newer preview was requested.
          if (token != _previewToken) return null;
          return bytes;
        });
      });
    }

    if (immediate) {
      start();
    } else {
      _previewDebounce = Timer(const Duration(milliseconds: 350), start);
    }
  }

  void _bumpPreview() => _reloadPreview();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Material(
      color: scheme.surface,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.sheetTitle,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Preview',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(color: scheme.outlineVariant),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(11),
                child: SizedBox(
                  height: widget.previewHeight,
                  width: double.infinity,
                  child: !widget.hasSelection
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              'Select one or more cards to preview the PDF.',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        )
                      : FutureBuilder<Uint8List?>(
                          key: ValueKey(_previewToken),
                          future: _previewFuture,
                          builder: (context, snapshot) {
                            if (snapshot.connectionState !=
                                ConnectionState.done) {
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            }
                            if (snapshot.hasError) {
                              return Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Text(
                                    'Preview failed: ${snapshot.error}',
                                    textAlign: TextAlign.center,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: scheme.error,
                                    ),
                                  ),
                                ),
                              );
                            }
                            final bytes = snapshot.data;
                            if (bytes == null || bytes.isEmpty) {
                              return Center(
                                child: Text(
                                  'Preview unavailable.',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                              );
                            }
                            return _PdfBytesFirstPagePreview(
                              bytes: bytes,
                              sourceName: 'spell-export-$_previewToken',
                            );
                          },
                        ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Card theme',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            InputDecorator(
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                isDense: true,
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<CardExportThemeSelection>(
                  isExpanded: true,
                  value: cardExportTheme,
                  items: [
                    const DropdownMenuItem(
                      value: CardExportMatchApp(),
                      child: Text('Match app'),
                    ),
                    const DropdownMenuItem(
                      value: CardExportPrintFriendly(),
                      child: Text('Print-friendly'),
                    ),
                    for (final id in AppThemeId.values)
                      DropdownMenuItem(
                        value: CardExportAppTheme(id),
                        child: Text(id.label),
                      ),
                  ],
                  onChanged: (v) {
                    if (v == null || v == cardExportTheme) return;
                    setState(() => cardExportTheme = v);
                    _bumpPreview();
                  },
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Cards per sheet',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            SegmentedButton<PdfGridPreset>(
              segments: [
                for (final p in PdfGridPreset.values)
                  ButtonSegment<PdfGridPreset>(value: p, label: Text(p.label)),
              ],
              selected: {grid},
              onSelectionChanged: (next) {
                if (next.isEmpty) return;
                final selected = next.first;
                if (selected == grid) return;
                setState(() => grid = selected);
                _bumpPreview();
              },
            ),
            const SizedBox(height: 16),
            Text(
              'Page margin (${pageMargin.round()} pt)',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            Slider(
              min: 8,
              max: 48,
              divisions: 8,
              value: pageMargin.clamp(8, 48),
              label: '${pageMargin.round()}',
              onChanged: (v) => setState(() => pageMargin = v),
              onChangeEnd: (_) => _bumpPreview(),
            ),
            Text(
              'Space between cards (${cardGap.round()} pt)',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            Slider(
              min: 4,
              max: 20,
              divisions: 8,
              value: cardGap.clamp(4, 20),
              label: '${cardGap.round()}',
              onChanged: (v) => setState(() => cardGap = v),
              onChangeEnd: (_) => _bumpPreview(),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => widget.onGenerate(
                cardExportTheme: cardExportTheme,
                cardsPerRow: grid.cardsPerRow,
                cardsPerColumn: grid.cardsPerColumn,
                pageMargin: pageMargin,
                cardGap: cardGap,
              ),
              icon: const Icon(Icons.picture_as_pdf_outlined),
              label: const Text('Generate PDF'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PdfBytesFirstPagePreview extends StatelessWidget {
  const _PdfBytesFirstPagePreview({
    required this.bytes,
    required this.sourceName,
  });

  final Uint8List bytes;
  final String sourceName;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return PdfDocumentViewBuilder(
      documentRef: PdfDocumentRefData(
        bytes,
        sourceName: sourceName,
      ),
      loadingBuilder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
      errorBuilder: (context, error, stackTrace) => Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Could not load PDF preview',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
        ),
      ),
      builder: (context, document) {
        if (document == null || document.pages.isEmpty) {
          return Center(
            child: Text(
              'PDF has no pages',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
          );
        }
        return PdfPageView(
          document: document,
          pageNumber: 1,
          alignment: Alignment.center,
        );
      },
    );
  }
}
