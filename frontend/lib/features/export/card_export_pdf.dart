import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../core/ui/mtg_card_layout.dart';
import '../player_options/items/data/item_model.dart';
import '../player_options/items/ui/item_sheet.dart';
import '../player_options/spells/data/spell_model.dart';
import '../player_options/spells/ui/spell_sheet.dart';

export 'card_export_present.dart' show presentCardExportPdf;

/// Light grayscale theme for low-ink / print-friendly PDF cards.
ThemeData printFriendlyCardExportTheme() {
  const surface = Color(0xFFF7F7F7);
  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.light(
      primary: const Color(0xFF424242),
      onPrimary: Colors.white,
      primaryContainer: const Color(0xFFDEDEDE),
      onPrimaryContainer: const Color(0xFF1C1B1F),
      secondary: const Color(0xFF5C5C5C),
      onSecondary: Colors.white,
      surface: Colors.white,
      onSurface: const Color(0xFF1C1B1F),
      surfaceContainerLowest: surface,
      surfaceContainerHighest: const Color(0xFFE8E8E8),
      tertiary: const Color(0xFF555555),
      onTertiary: Colors.white,
      inverseSurface: const Color(0xFF313033),
      onInverseSurface: const Color(0xFFF4EFF4),
    ),
  );
}

Future<void> _waitForCardLayout() async {
  for (var i = 0; i < 5; i++) {
    await WidgetsBinding.instance.endOfFrame;
  }
  await Future<void>.delayed(const Duration(milliseconds: 48));
}

Future<Uint8List> _captureCardWidget({
  required BuildContext context,
  required GlobalKey boundaryKey,
  required Widget card,
  required ThemeData theme,
}) async {
  final overlay = Overlay.of(context, rootOverlay: true);
  final mq = MediaQuery.of(context);
  final devicePixelRatio = mq.devicePixelRatio;

  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (ctx) => Positioned(
      left: -16000,
      top: 0,
      child: Material(
        color: Colors.transparent,
        child: Theme(
          data: theme,
          child: MediaQuery(
            data: mq.copyWith(
              size: const Size(
                kMtgTargetWidthLogical,
                kMtgTargetHeightLogical,
              ),
              padding: EdgeInsets.zero,
              viewPadding: EdgeInsets.zero,
              viewInsets: EdgeInsets.zero,
            ),
            child: RepaintBoundary(
              key: boundaryKey,
              child: SizedBox(
                width: kMtgTargetWidthLogical,
                height: kMtgTargetHeightLogical,
                child: card,
              ),
            ),
          ),
        ),
      ),
    ),
  );

  overlay.insert(entry);
  try {
    await _waitForCardLayout();
    final boundary = boundaryKey.currentContext?.findRenderObject();
    if (boundary is! RenderRepaintBoundary) {
      throw StateError('RepaintBoundary not ready.');
    }
    final pixelRatio = math.max(3.0, devicePixelRatio);
    final image = await boundary.toImage(pixelRatio: pixelRatio);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    if (byteData == null) {
      throw StateError('Failed to encode PNG.');
    }
    return byteData.buffer.asUint8List();
  } finally {
    entry.remove();
  }
}

/// Rasterizes a [SpellSheet] at full card resolution to PNG bytes (first page).
Future<Uint8List> rasterizeSpellCard({
  required BuildContext context,
  required Spell spell,
  required ThemeData theme,
  List<String> classNames = const [],
  List<String> tagNames = const [],
}) async {
  final pages = await rasterizeSpellCards(
    context: context,
    spell: spell,
    theme: theme,
    classNames: classNames,
    tagNames: tagNames,
  );
  return pages.first;
}

Future<List<Uint8List>> rasterizeSpellCards({
  required BuildContext context,
  required Spell spell,
  required ThemeData theme,
  List<String> classNames = const [],
  List<String> tagNames = const [],
}) async {
  final key = GlobalKey();
  final out = <Uint8List>[];
  for (final sheet in buildSpellSheets(
    spell,
    classNames: classNames,
    tagNames: tagNames,
  )) {
    out.add(
      await _captureCardWidget(
        context: context,
        boundaryKey: key,
        theme: theme,
        card: sheet,
      ),
    );
  }
  return out;
}

Future<Uint8List> rasterizeItemCard({
  required BuildContext context,
  required Item item,
  required ThemeData theme,
}) async {
  final pages = await rasterizeItemCards(
    context: context,
    item: item,
    theme: theme,
  );
  return pages.first;
}

Future<List<Uint8List>> rasterizeItemCards({
  required BuildContext context,
  required Item item,
  required ThemeData theme,
}) async {
  final key = GlobalKey();
  final out = <Uint8List>[];
  for (final sheet in buildItemSheets(item)) {
    out.add(
      await _captureCardWidget(
        context: context,
        boundaryKey: key,
        theme: theme,
        card: sheet,
      ),
    );
  }
  return out;
}

/// Builds a PDF of card images on A4 pages.
///
/// Cards are scaled to fit the chosen [cardsPerRow] × [cardsPerColumn] grid
/// inside the printable area (margins + gaps), preserving Magic card aspect.
Future<Uint8List> buildCardsPdf({
  required List<Uint8List> pngBytesList,
  required String title,
  bool includeCoverPage = true,
  int cardsPerRow = 2,
  int cardsPerColumn = 2,
  double pageMargin = 40,
  double cardGap = 12,
}) async {
  final doc = pw.Document();
  final images = pngBytesList.map(pw.MemoryImage.new).toList();
  final safeCardsPerRow = math.max(1, cardsPerRow);
  final safeCardsPerColumn = math.max(1, cardsPerColumn);
  final safeMargin = math.max(0.0, pageMargin).toDouble();
  final safeGap = math.max(0.0, cardGap).toDouble();

  final pageW = PdfPageFormat.a4.width;
  final pageH = PdfPageFormat.a4.height;
  final availW = math.max(1.0, pageW - 2 * safeMargin);
  final availH = math.max(1.0, pageH - 2 * safeMargin);
  final cellW =
      (availW - safeGap * (safeCardsPerRow - 1)) / safeCardsPerRow;
  final cellH =
      (availH - safeGap * (safeCardsPerColumn - 1)) / safeCardsPerColumn;

  // Prefer Magic aspect; never exceed the cell.
  const cardAspect = kMtgCardAspectRatio; // width / height
  var drawW = cellW;
  var drawH = drawW / cardAspect;
  if (drawH > cellH) {
    drawH = cellH;
    drawW = drawH * cardAspect;
  }

  if (includeCoverPage) {
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (c) => pw.Center(
          child: pw.Column(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              pw.Text(title, style: const pw.TextStyle(fontSize: 22)),
              pw.SizedBox(height: 16),
              pw.Text('${pngBytesList.length} cards'),
              pw.SizedBox(height: 8),
              pw.Text(
                _coverTimestampAscii(),
                style: const pw.TextStyle(fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }

  final perPage = safeCardsPerRow * safeCardsPerColumn;
  for (var pageStart = 0; pageStart < images.length; pageStart += perPage) {
    final end = math.min(pageStart + perPage, images.length);
    final slice = images.sublist(pageStart, end);
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.all(safeMargin),
        build: (c) {
          return pw.SizedBox(
            width: availW,
            height: availH,
            child: pw.Stack(
              children: [
                for (var i = 0; i < slice.length; i++)
                  pw.Positioned(
                    left: (i % safeCardsPerRow) * (cellW + safeGap) +
                        (cellW - drawW) / 2,
                    top: (i ~/ safeCardsPerRow) * (cellH + safeGap) +
                        (cellH - drawH) / 2,
                    child: pw.Image(
                      slice[i],
                      width: drawW,
                      height: drawH,
                      fit: pw.BoxFit.fill,
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  return doc.save();
}

String _coverTimestampAscii() {
  final d = DateTime.now().toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${d.year}-${two(d.month)}-${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
}
