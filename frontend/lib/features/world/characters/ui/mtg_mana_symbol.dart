import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/character_model.dart';

/// Circular MTG-style mana pip with a stylized color symbol.
class MtgManaSymbol extends StatelessWidget {
  const MtgManaSymbol({
    super.key,
    required this.color,
    this.size = 28,
    this.selected = true,
    this.showBorder = true,
  });

  final MtgColor color;
  final double size;
  final bool selected;
  final bool showBorder;

  @override
  Widget build(BuildContext context) {
    final fill = Color(color.colorArgb);
    final ink = Color(color.onColorArgb);
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: color.displayName,
      child: Opacity(
        opacity: selected ? 1 : 0.42,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: fill,
            shape: BoxShape.circle,
            border: showBorder
                ? Border.all(
                    color: selected
                        ? scheme.outline.withValues(alpha: 0.55)
                        : scheme.outlineVariant,
                    width: selected ? 1.5 : 1,
                  )
                : null,
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: fill.withValues(alpha: 0.35),
                      blurRadius: size * 0.15,
                      offset: Offset(0, size * 0.04),
                    ),
                  ]
                : null,
          ),
          child: CustomPaint(
            painter: _MtgManaPainter(
              color: color,
              ink: ink,
              pipFill: fill,
            ),
          ),
        ),
      ),
    );
  }
}

class _MtgManaPainter extends CustomPainter {
  const _MtgManaPainter({
    required this.color,
    required this.ink,
    required this.pipFill,
  });

  final MtgColor color;
  final Color ink;
  final Color pipFill;

  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()
      ..color = ink
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    final hole = Paint()
      ..color = pipFill
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final center = Offset(size.width / 2, size.height / 2);
    final r = size.shortestSide / 2;

    switch (color) {
      case MtgColor.white:
        _paintSun(canvas, center, r, fill);
      case MtgColor.blue:
        _paintDroplet(canvas, center, r, fill);
      case MtgColor.black:
        _paintSkull(canvas, center, r, fill, hole);
      case MtgColor.red:
        _paintFireball(canvas, center, r, fill, hole);
      case MtgColor.green:
        _paintTree(canvas, center, r, fill);
    }
  }

  void _paintSun(Canvas canvas, Offset c, double r, Paint fill) {
    final coreR = r * 0.28;
    canvas.drawCircle(c, coreR, fill);

    final rayInner = r * 0.38;
    final rayOuter = r * 0.72;
    for (var i = 0; i < 8; i++) {
      final a = (i / 8) * math.pi * 2 - math.pi / 2;
      final tip = Offset(
        c.dx + math.cos(a) * rayOuter,
        c.dy + math.sin(a) * rayOuter,
      );
      final left = Offset(
        c.dx + math.cos(a - 0.18) * rayInner,
        c.dy + math.sin(a - 0.18) * rayInner,
      );
      final right = Offset(
        c.dx + math.cos(a + 0.18) * rayInner,
        c.dy + math.sin(a + 0.18) * rayInner,
      );
      canvas.drawPath(
        Path()
          ..moveTo(tip.dx, tip.dy)
          ..lineTo(left.dx, left.dy)
          ..lineTo(right.dx, right.dy)
          ..close(),
        fill,
      );
    }

    canvas.drawCircle(
      c,
      coreR * 0.55,
      Paint()
        ..color = pipFill
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.06
        ..isAntiAlias = true,
    );
  }

  void _paintDroplet(Canvas canvas, Offset c, double r, Paint fill) {
    final path = Path()
      ..moveTo(c.dx, c.dy - r * 0.62)
      ..quadraticBezierTo(
        c.dx - r * 0.05,
        c.dy - r * 0.15,
        c.dx - r * 0.38,
        c.dy + r * 0.12,
      )
      ..quadraticBezierTo(
        c.dx - r * 0.35,
        c.dy + r * 0.6,
        c.dx,
        c.dy + r * 0.55,
      )
      ..quadraticBezierTo(
        c.dx + r * 0.35,
        c.dy + r * 0.6,
        c.dx + r * 0.38,
        c.dy + r * 0.12,
      )
      ..quadraticBezierTo(
        c.dx + r * 0.05,
        c.dy - r * 0.15,
        c.dx,
        c.dy - r * 0.62,
      )
      ..close();
    canvas.drawPath(path, fill);
  }

  void _paintSkull(
    Canvas canvas,
    Offset c,
    double r,
    Paint fill,
    Paint hole,
  ) {
    final skull = Path()
      ..addOval(
        Rect.fromCenter(
          center: Offset(c.dx, c.dy - r * 0.08),
          width: r * 1.05,
          height: r * 1.0,
        ),
      )
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(c.dx, c.dy + r * 0.28),
            width: r * 0.72,
            height: r * 0.42,
          ),
          Radius.circular(r * 0.12),
        ),
      );
    canvas.drawPath(skull, fill);

    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(c.dx - r * 0.22, c.dy - r * 0.08),
        width: r * 0.28,
        height: r * 0.32,
      ),
      hole,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(c.dx + r * 0.22, c.dy - r * 0.08),
        width: r * 0.28,
        height: r * 0.32,
      ),
      hole,
    );

    canvas.drawPath(
      Path()
        ..moveTo(c.dx, c.dy + r * 0.02)
        ..lineTo(c.dx - r * 0.08, c.dy + r * 0.2)
        ..lineTo(c.dx + r * 0.08, c.dy + r * 0.2)
        ..close(),
      hole,
    );

    for (final x in [-0.16, 0.0, 0.16]) {
      canvas.drawLine(
        Offset(c.dx + r * x, c.dy + r * 0.3),
        Offset(c.dx + r * x, c.dy + r * 0.44),
        Paint()
          ..color = pipFill
          ..strokeWidth = r * 0.055
          ..strokeCap = StrokeCap.round
          ..isAntiAlias = true,
      );
    }
  }

  void _paintFireball(
    Canvas canvas,
    Offset c,
    double r,
    Paint fill,
    Paint hole,
  ) {
    final path = Path()
      ..moveTo(c.dx + r * 0.05, c.dy - r * 0.62)
      ..quadraticBezierTo(
        c.dx + r * 0.55,
        c.dy - r * 0.35,
        c.dx + r * 0.48,
        c.dy + r * 0.05,
      )
      ..quadraticBezierTo(
        c.dx + r * 0.55,
        c.dy + r * 0.45,
        c.dx,
        c.dy + r * 0.58,
      )
      ..quadraticBezierTo(
        c.dx - r * 0.55,
        c.dy + r * 0.42,
        c.dx - r * 0.42,
        c.dy - r * 0.05,
      )
      ..quadraticBezierTo(
        c.dx - r * 0.55,
        c.dy - r * 0.45,
        c.dx - r * 0.1,
        c.dy - r * 0.35,
      )
      ..quadraticBezierTo(
        c.dx - r * 0.02,
        c.dy - r * 0.55,
        c.dx + r * 0.05,
        c.dy - r * 0.62,
      )
      ..close();
    canvas.drawPath(path, fill);

    canvas.drawPath(
      Path()
        ..moveTo(c.dx - r * 0.05, c.dy - r * 0.28)
        ..quadraticBezierTo(
          c.dx + r * 0.28,
          c.dy - r * 0.05,
          c.dx + r * 0.05,
          c.dy + r * 0.3,
        ),
      Paint()
        ..color = pipFill
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.1
        ..strokeCap = StrokeCap.round
        ..isAntiAlias = true,
    );
    canvas.drawCircle(
      Offset(c.dx - r * 0.12, c.dy + r * 0.05),
      r * 0.12,
      hole,
    );
  }

  void _paintTree(Canvas canvas, Offset c, double r, Paint fill) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(c.dx, c.dy + r * 0.38),
          width: r * 0.22,
          height: r * 0.45,
        ),
        Radius.circular(r * 0.04),
      ),
      fill,
    );

    final canopy = Path()
      ..addOval(
        Rect.fromCenter(
          center: Offset(c.dx, c.dy - r * 0.22),
          width: r * 0.95,
          height: r * 0.85,
        ),
      )
      ..addOval(
        Rect.fromCenter(
          center: Offset(c.dx - r * 0.28, c.dy - r * 0.02),
          width: r * 0.55,
          height: r * 0.5,
        ),
      )
      ..addOval(
        Rect.fromCenter(
          center: Offset(c.dx + r * 0.28, c.dy - r * 0.02),
          width: r * 0.55,
          height: r * 0.5,
        ),
      )
      ..addOval(
        Rect.fromCenter(
          center: Offset(c.dx, c.dy + r * 0.05),
          width: r * 0.7,
          height: r * 0.45,
        ),
      );
    canvas.drawPath(canopy, fill);
  }

  @override
  bool shouldRepaint(covariant _MtgManaPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.ink != ink ||
      oldDelegate.pipFill != pipFill;
}
