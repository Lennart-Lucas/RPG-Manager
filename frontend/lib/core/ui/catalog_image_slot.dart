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

/// Rewrites Google Drive share/view links into a direct image URL.
///
/// Example:
/// `https://drive.google.com/file/d/FILE_ID/view?usp=sharing`
/// → `https://drive.google.com/uc?export=view&id=FILE_ID`
///
/// Other URLs are returned trimmed and unchanged. Drive still needs the file
/// shared as "Anyone with the link"; some browsers may block the request.
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

  // Already the preferred direct form.
  if ((uri.path == '/uc' || uri.path.endsWith('/uc')) &&
      uri.queryParameters['export'] == 'view' &&
      uri.queryParameters['id'] == fileId) {
    return text;
  }

  return Uri.https('drive.google.com', '/uc', {
    'export': 'view',
    'id': fileId,
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

    return AspectRatio(
      aspectRatio: aspectRatio,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surfaceContainer,
          borderRadius: BorderRadius.circular(borderRadius),
          border: Border.all(color: border),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius),
          child: url.isEmpty
              ? placeholder
              : Image.network(
                  url,
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
                ),
        ),
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

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: SizedBox(
        width: size,
        height: size,
        child: Image.network(
          url,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => fallback,
        ),
      ),
    );
  }
}
