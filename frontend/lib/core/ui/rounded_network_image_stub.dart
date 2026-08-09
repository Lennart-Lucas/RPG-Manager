import 'package:flutter/material.dart';

Widget buildRoundedNetworkImage({
  required String url,
  required double borderRadius,
  required Widget Function(BuildContext, Object, StackTrace?) errorBuilder,
  BoxFit fit = BoxFit.cover,
  Alignment alignment = Alignment.center,
  double? width,
  double? height,
  ImageLoadingBuilder? loadingBuilder,
}) {
  return ClipRRect(
    borderRadius: BorderRadius.circular(borderRadius),
    child: Image.network(
      url,
      fit: fit,
      alignment: alignment,
      width: width,
      height: height,
      errorBuilder: errorBuilder,
      loadingBuilder: loadingBuilder,
    ),
  );
}

Widget buildRoundedFitWidthNetworkImage({
  required String url,
  required double borderRadius,
  required double placeholderAspectRatio,
  required double minAspectRatio,
  required Widget Function(BuildContext, Object, StackTrace?) errorBuilder,
  required Widget Function(BuildContext) loadingBuilder,
}) {
  return _FitWidthCappedImage(
    url: url,
    borderRadius: borderRadius,
    placeholderAspectRatio: placeholderAspectRatio,
    minAspectRatio: minAspectRatio,
    errorBuilder: errorBuilder,
    loadingBuilder: loadingBuilder,
  );
}

class _FitWidthCappedImage extends StatefulWidget {
  const _FitWidthCappedImage({
    required this.url,
    required this.borderRadius,
    required this.placeholderAspectRatio,
    required this.minAspectRatio,
    required this.errorBuilder,
    required this.loadingBuilder,
  });

  final String url;
  final double borderRadius;
  final double placeholderAspectRatio;
  final double minAspectRatio;
  final Widget Function(BuildContext, Object, StackTrace?) errorBuilder;
  final Widget Function(BuildContext) loadingBuilder;

  @override
  State<_FitWidthCappedImage> createState() => _FitWidthCappedImageState();
}

class _FitWidthCappedImageState extends State<_FitWidthCappedImage> {
  double? _naturalRatio;
  Object? _error;
  ImageStream? _stream;
  ImageStreamListener? _listener;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(covariant _FitWidthCappedImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _naturalRatio = null;
      _error = null;
      _resolve();
    }
  }

  @override
  void dispose() {
    _detach();
    super.dispose();
  }

  void _detach() {
    if (_stream != null && _listener != null) {
      _stream!.removeListener(_listener!);
    }
    _stream = null;
    _listener = null;
  }

  void _resolve() {
    _detach();
    final stream = NetworkImage(widget.url).resolve(ImageConfiguration.empty);
    late final ImageStreamListener listener;
    listener = ImageStreamListener(
      (info, _) {
        final w = info.image.width;
        final h = info.image.height;
        if (!mounted || w == 0 || h == 0) return;
        final next = w / h;
        if (_naturalRatio != next) {
          setState(() => _naturalRatio = next);
        }
      },
      onError: (error, _) {
        if (!mounted) return;
        setState(() => _error = error);
      },
    );
    _stream = stream;
    _listener = listener;
    stream.addListener(listener);
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return widget.errorBuilder(context, _error!, null);
    }

    final natural = _naturalRatio;
    final minRatio = widget.minAspectRatio;
    final displayRatio = natural == null
        ? widget.placeholderAspectRatio
        : (natural < minRatio ? minRatio : natural);
    final cropped = natural != null && natural < minRatio;

    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.borderRadius),
      child: AspectRatio(
        aspectRatio: displayRatio,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (natural == null) widget.loadingBuilder(context),
            Image.network(
              widget.url,
              fit: cropped || natural == null ? BoxFit.cover : BoxFit.fitWidth,
              width: double.infinity,
              height: double.infinity,
              alignment: Alignment.center,
              errorBuilder: widget.errorBuilder,
            ),
          ],
        ),
      ),
    );
  }
}
