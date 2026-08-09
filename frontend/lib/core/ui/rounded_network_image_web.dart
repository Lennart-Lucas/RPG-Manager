import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:web/web.dart' as web;

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
  return _WebRoundedImage(
    url: url,
    borderRadius: borderRadius,
    errorBuilder: errorBuilder,
    fit: fit,
    alignment: alignment,
    width: width,
    height: height,
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
  return _WebFitWidthRoundedImage(
    url: url,
    borderRadius: borderRadius,
    placeholderAspectRatio: placeholderAspectRatio,
    minAspectRatio: minAspectRatio,
    errorBuilder: errorBuilder,
    loadingBuilder: loadingBuilder,
  );
}

// #region agent log
void _agentLog({
  required String hypothesisId,
  required String location,
  required String message,
  required Map<String, Object?> data,
}) {
  http
      .post(
        Uri.parse(
          'http://127.0.0.1:7277/ingest/6a76c2b7-0d0c-42f0-879f-b33f045ca01b',
        ),
        headers: {
          'Content-Type': 'application/json',
          'X-Debug-Session-Id': '3f8c3c',
        },
        body: jsonEncode({
          'sessionId': '3f8c3c',
          'hypothesisId': hypothesisId,
          'location': location,
          'message': message,
          'data': data,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        }),
      )
      .catchError((_) => http.Response('', 500));
}
// #endregion

String _cssObjectFit(BoxFit fit) {
  return switch (fit) {
    BoxFit.contain => 'contain',
    BoxFit.fill => 'fill',
    BoxFit.scaleDown => 'scale-down',
    BoxFit.none || BoxFit.fitWidth || BoxFit.fitHeight => 'none',
    BoxFit.cover => 'cover',
  };
}

String _cssObjectPosition(Alignment alignment) {
  final x = (alignment.x + 1) / 2 * 100;
  final y = (alignment.y + 1) / 2 * 100;
  return '$x% $y%';
}

void _styleImg(
  web.HTMLImageElement img, {
  required String url,
  required double borderRadius,
  required BoxFit fit,
  required Alignment alignment,
  required bool heightAuto,
}) {
  img.src = url;
  img.alt = '';
  img.draggable = false;
  final style = img.style;
  style.width = '100%';
  style.height = heightAuto ? 'auto' : '100%';
  style.display = 'block';
  style.objectFit = _cssObjectFit(fit);
  style.objectPosition = _cssObjectPosition(alignment);
  style.borderRadius = '${borderRadius}px';
}

class _WebRoundedImage extends StatefulWidget {
  const _WebRoundedImage({
    required this.url,
    required this.borderRadius,
    required this.errorBuilder,
    required this.fit,
    required this.alignment,
    this.width,
    this.height,
  });

  final String url;
  final double borderRadius;
  final Widget Function(BuildContext, Object, StackTrace?) errorBuilder;
  final BoxFit fit;
  final Alignment alignment;
  final double? width;
  final double? height;

  @override
  State<_WebRoundedImage> createState() => _WebRoundedImageState();
}

class _WebRoundedImageState extends State<_WebRoundedImage> {
  Object? _error;

  @override
  void didUpdateWidget(covariant _WebRoundedImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) _error = null;
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return widget.errorBuilder(context, _error!, null);
    }

    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: HtmlElementView.fromTagName(
        tagName: 'img',
        onElementCreated: (element) {
          final img = element as web.HTMLImageElement;
          _styleImg(
            img,
            url: widget.url,
            borderRadius: widget.borderRadius,
            fit: widget.fit,
            alignment: widget.alignment,
            heightAuto: false,
          );
          img.onError.listen((_) {
            if (!mounted) return;
            setState(() => _error = Exception('Failed to load image'));
          });
        },
      ),
    );
  }
}

class _WebFitWidthRoundedImage extends StatefulWidget {
  const _WebFitWidthRoundedImage({
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
  State<_WebFitWidthRoundedImage> createState() =>
      _WebFitWidthRoundedImageState();
}

class _WebFitWidthRoundedImageState extends State<_WebFitWidthRoundedImage> {
  double? _aspectRatio;
  Object? _error;
  bool _loggedLoad = false;

  @override
  void didUpdateWidget(covariant _WebFitWidthRoundedImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _aspectRatio = null;
      _error = null;
      _loggedLoad = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return widget.errorBuilder(context, _error!, null);
    }

    final natural = _aspectRatio;
    final minRatio = widget.minAspectRatio;
    final displayRatio = natural == null
        ? widget.placeholderAspectRatio
        : (natural < minRatio ? minRatio : natural);
    final cropped = natural != null && natural < minRatio;

    return AspectRatio(
      aspectRatio: displayRatio,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (natural == null) widget.loadingBuilder(context),
          HtmlElementView.fromTagName(
            tagName: 'img',
            onElementCreated: (element) {
              final img = element as web.HTMLImageElement;
              _styleImg(
                img,
                url: widget.url,
                borderRadius: widget.borderRadius,
                fit: BoxFit.cover,
                alignment: Alignment.center,
                heightAuto: false,
              );
              img.onLoad.listen((_) {
                final w = img.naturalWidth;
                final h = img.naturalHeight;
                if (!mounted || w == 0 || h == 0) return;
                final next = w / h;
                // #region agent log
                if (!_loggedLoad) {
                  _loggedLoad = true;
                  _agentLog(
                    hypothesisId: 'A',
                    location: 'rounded_network_image_web.dart:onLoad',
                    message: 'web image capped aspect',
                    data: {
                      'runId': 'post-fix',
                      'naturalWidth': w,
                      'naturalHeight': h,
                      'naturalRatio': next,
                      'minAspectRatio': minRatio,
                      'displayRatio':
                          next < minRatio ? minRatio : next,
                      'cropped': next < minRatio,
                      'urlHost': Uri.tryParse(widget.url)?.host,
                    },
                  );
                }
                // #endregion
                if (_aspectRatio != next) {
                  setState(() => _aspectRatio = next);
                }
              });
              img.onError.listen((_) {
                if (!mounted) return;
                setState(() => _error = Exception('Failed to load image'));
              });
            },
          ),
        ],
      ),
    );
  }
}
