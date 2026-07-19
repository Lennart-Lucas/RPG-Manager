import 'package:flutter/material.dart';

import 'simple_card_rich_text.dart';

/// Default largest rules-body font (logical px).
const double kMtgCardRulesMaxFontSize = 12.5;

/// Name line is this factor × [maxFontSize].
const double kMtgCardTitleToRulesMaxFontScale = 1.2;

/// Shares a common rules-text scale across multiple cards.
class MtgCardRulesScaleController extends ChangeNotifier {
  double? _sharedScale;

  double? get sharedScale => _sharedScale;

  void offerScale(double value) {
    if (value.isNaN || value.isInfinite || value <= 0) return;
    if (_sharedScale == null || value < _sharedScale! - 0.0005) {
      _sharedScale = value;
      notifyListeners();
    }
  }
}

/// Body text for MTG-sized cards: scales to fit the rules area (no scroll).
class MtgCardRulesTextFit extends StatefulWidget {
  final String content;
  final Color onSurface;
  final double maxFontSize;
  final MtgCardRulesScaleController? scaleController;

  const MtgCardRulesTextFit({
    super.key,
    required this.content,
    required this.onSurface,
    this.maxFontSize = kMtgCardRulesMaxFontSize,
    this.scaleController,
  });

  @override
  State<MtgCardRulesTextFit> createState() => _MtgCardRulesTextFitState();
}

class _MtgCardRulesTextFitState extends State<MtgCardRulesTextFit> {
  static const double _kBaseFont = 11.5;
  static const double _kBaseHeight = 1.25;
  static const double _kMinScale = 0.3;
  static const int _kMaxBinaryIters = 16;

  int _phase = 0;
  int _binaryIter = 0;
  double? _lo;
  double? _hi;

  double _scale = 1.0;
  final GlobalKey _measureKey = GlobalKey();
  double? _heightBudget;
  double? _prevLayoutMaxH;

  double get _maxScale => widget.maxFontSize / _kBaseFont;

  @override
  void initState() {
    super.initState();
    _scale =
        widget.scaleController?.sharedScale?.clamp(_kMinScale, _maxScale) ??
            _maxScale;
    widget.scaleController?.addListener(_onSharedScaleChanged);
  }

  @override
  void didUpdateWidget(covariant MtgCardRulesTextFit oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scaleController != widget.scaleController) {
      oldWidget.scaleController?.removeListener(_onSharedScaleChanged);
      widget.scaleController?.addListener(_onSharedScaleChanged);
      _onSharedScaleChanged();
    }
    if (widget.content != oldWidget.content ||
        widget.maxFontSize != oldWidget.maxFontSize) {
      _beginFit();
    }
  }

  @override
  void dispose() {
    widget.scaleController?.removeListener(_onSharedScaleChanged);
    super.dispose();
  }

  void _onSharedScaleChanged() {
    if (!mounted) return;
    final shared = widget.scaleController?.sharedScale;
    if (shared == null) return;
    final clamped = shared.clamp(_kMinScale, _maxScale);
    if ((_scale - clamped).abs() < 0.001) return;
    setState(() => _scale = clamped);
  }

  void _beginFit() {
    if (!mounted) return;
    _phase = 0;
    _binaryIter = 0;
    _lo = null;
    _hi = null;
    setState(() {
      _scale = _maxScale;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _fitStep());
  }

  void _fitStep() {
    if (!mounted) return;
    final maxH = _heightBudget;
    if (maxH == null || maxH.isInfinite || maxH <= 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _fitStep());
      return;
    }
    final box = _measureKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _fitStep());
      return;
    }
    final h = box.size.height;
    final maxScale = _maxScale;

    if (_phase == 0) {
      if (h <= maxH + 1.0) {
        if ((_scale - maxScale).abs() > 0.001) {
          setState(() => _scale = maxScale);
        }
        return;
      }
      _phase = 1;
      setState(() => _scale = _kMinScale);
      WidgetsBinding.instance.addPostFrameCallback((_) => _fitStep());
      return;
    }

    if (_phase == 1) {
      if (h > maxH + 0.5) {
        setState(() => _scale = _kMinScale);
        return;
      }
      _phase = 2;
      _lo = _kMinScale;
      _hi = maxScale;
      _binaryIter = 0;
      setState(() => _scale = ((_lo! + _hi!) / 2).clamp(_kMinScale, maxScale));
      WidgetsBinding.instance.addPostFrameCallback((_) => _fitStep());
      return;
    }

    if (_phase == 2) {
      if (h <= maxH + 0.75) {
        _lo = _scale;
      } else {
        _hi = _scale;
      }

      if (_hi! - _lo! < 0.004 || _binaryIter >= _kMaxBinaryIters) {
        final resolved = _lo!.clamp(_kMinScale, maxScale);
        setState(() => _scale = resolved);
        widget.scaleController?.offerScale(resolved);
        _phase = 0;
        _lo = null;
        _hi = null;
        return;
      }

      _binaryIter++;
      setState(() {
        _scale = ((_lo! + _hi!) / 2).clamp(_kMinScale, maxScale);
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _fitStep());
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _heightBudget = constraints.maxHeight;
        final w = constraints.maxWidth;
        final maxH = constraints.maxHeight;

        final mh = maxH.isFinite ? maxH : 0.0;
        if (mh > 0) {
          if (_prevLayoutMaxH == null || (mh - _prevLayoutMaxH!).abs() > 0.5) {
            _prevLayoutMaxH = mh;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _beginFit();
            });
          }
        }

        return SizedBox(
          width: w,
          height: maxH,
          child: ClipRect(
            child: OverflowBox(
              alignment: Alignment.topLeft,
              minWidth: w,
              maxWidth: w,
              minHeight: 0,
              maxHeight: double.infinity,
              child: SizedBox(
                key: _measureKey,
                width: w,
                child: SimpleCardRichText(
                  content: widget.content,
                  styleScale: _scale,
                  baseStyle: TextStyle(
                    color: widget.onSurface,
                    fontSize: _kBaseFont * _scale,
                    height: _kBaseHeight,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
