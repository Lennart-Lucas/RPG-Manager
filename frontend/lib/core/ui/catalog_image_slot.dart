import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Returns an error message if [value] is non-empty and not an http(s) URL.
String? validateOptionalHttpUrl(String? value) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) return null;
  final uri = Uri.tryParse(text);
  if (uri == null ||
      !uri.hasScheme ||
      (uri.scheme != 'http' && uri.scheme != 'https') ||
      uri.host.isEmpty) {
    return 'Enter a valid http(s) URL';
  }
  return null;
}

/// Rewrites Google Drive share/view/`uc` links into an embeddable thumbnail URL.
///
/// Example:
/// `https://drive.google.com/file/d/FILE_ID/view?usp=sharing`
/// → `https://drive.google.com/thumbnail?id=FILE_ID&sz=w2000`
///
/// Drive's `/uc?export=view` endpoints return 403 when embedded in websites
/// (third-party cookie changes). Thumbnails still work for "Anyone with the
/// link" files. Other URLs are returned trimmed and unchanged.
String normalizeCatalogImageUrl(String raw) {
  final text = raw.trim();
  if (text.isEmpty) return text;

  final uri = Uri.tryParse(text);
  if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
    return text;
  }

  final host = uri.host.toLowerCase();
  if (host != 'drive.google.com' && host != 'docs.google.com') {
    return text;
  }

  final fileId = _googleDriveFileId(uri);
  if (fileId == null) return text;

  // Prefer thumbnail — `/uc` is blocked for cross-site <img> embeds.
  if (uri.path == '/thumbnail' || uri.path.endsWith('/thumbnail')) {
    final sz = uri.queryParameters['sz'];
    if (uri.queryParameters['id'] == fileId && sz != null && sz.isNotEmpty) {
      return text;
    }
  }

  return Uri.https('drive.google.com', '/thumbnail', {
    'id': fileId,
    'sz': 'w2000',
  }).toString();
}

String? _googleDriveFileId(Uri uri) {
  final segments = uri.pathSegments;
  for (var i = 0; i + 2 < segments.length; i++) {
    if (segments[i] == 'file' && segments[i + 1] == 'd') {
      final id = segments[i + 2].trim();
      if (id.isNotEmpty) return id;
    }
  }

  final fromQuery = uri.queryParameters['id']?.trim();
  if (fromQuery != null && fromQuery.isNotEmpty) return fromQuery;
  return null;
}

Widget _networkImage({
  required String url,
  required Widget Function(BuildContext, Object, StackTrace?) errorBuilder,
  BoxFit fit = BoxFit.cover,
  double? width,
  double? height,
  ImageLoadingBuilder? loadingBuilder,
}) {
  return Image.network(
    url,
    fit: fit,
    width: width,
    height: height,
    // Prefer HTML <img> on web: CanvasKit cannot decode cross-origin bytes
    // without CORS, and ClipRRect/platform-view fallback is unreliable.
    webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
    errorBuilder: errorBuilder,
    loadingBuilder: loadingBuilder,
  );
}

/// 4:3 image slot for overview / detail panels. Falls back to [placeholder]
/// when [imageUrl] is empty or fails to load.
class CatalogImageSlot extends StatelessWidget {
  const CatalogImageSlot({
    super.key,
    required this.imageUrl,
    required this.placeholder,
    this.aspectRatio = 4 / 3,
    this.borderRadius = 8,
    this.borderColor,
  });

  final String imageUrl;
  final Widget placeholder;
  final double aspectRatio;
  final double borderRadius;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final border = borderColor ?? scheme.outline.withValues(alpha: 0.55);
    final url = normalizeCatalogImageUrl(imageUrl);
    final radius = BorderRadius.circular(borderRadius);

    Widget child;
    if (url.isEmpty) {
      child = placeholder;
    } else {
      final image = _networkImage(
        url: url,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, _, _) => placeholder,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return Center(
            child: SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                value: progress.expectedTotalBytes != null
                    ? progress.cumulativeBytesLoaded /
                        progress.expectedTotalBytes!
                    : null,
              ),
            ),
          );
        },
      );
      // ClipRRect hides HTML platform-view images on Flutter web.
      child = kIsWeb ? image : ClipRRect(borderRadius: radius, child: image);
    }

    return AspectRatio(
      aspectRatio: aspectRatio,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surfaceContainer,
          borderRadius: radius,
          border: Border.all(color: border),
        ),
        child: child,
      ),
    );
  }
}

/// Small square thumbnail for list tiles.
class CatalogImageThumb extends StatelessWidget {
  const CatalogImageThumb({
    super.key,
    required this.imageUrl,
    required this.fallback,
    this.size = 42,
    this.borderRadius = 13,
  });

  final String imageUrl;
  final Widget fallback;
  final double size;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final url = normalizeCatalogImageUrl(imageUrl);
    if (url.isEmpty) return fallback;

    final image = _networkImage(
      url: url,
      fit: BoxFit.cover,
      width: size,
      height: size,
      errorBuilder: (_, _, _) => fallback,
    );

    // Avoid ClipRRect on web — it blanks HTML platform-view images.
    if (kIsWeb) {
      return SizedBox(width: size, height: size, child: image);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: SizedBox(width: size, height: size, child: image),
    );
  }
}
