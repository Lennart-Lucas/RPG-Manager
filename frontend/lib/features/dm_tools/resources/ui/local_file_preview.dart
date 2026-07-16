import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:pdfrx/pdfrx.dart';

/// Non-blocking preview of a local file's first page / image.
class LocalFilePreview extends StatelessWidget {
  const LocalFilePreview({super.key, required this.path});

  final String path;

  /// Previous PDF preview height was 360; show first page at 2x.
  static const double pageHeight = 720;
  static const double boxPadding = 16;

  static const _imageExts = {
    '.png',
    '.jpg',
    '.jpeg',
    '.gif',
    '.webp',
    '.bmp',
  };

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return const SizedBox.shrink();
    }

    final ext = p.extension(path).toLowerCase();
    if (ext == '.pdf') {
      return _PdfFirstPagePreview(path: path);
    }
    if (_imageExts.contains(ext)) {
      return _ImagePreview(path: path);
    }
    return _PreviewShell(
      child: Text(
        'Preview not available for this file type',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
      ),
    );
  }
}

/// Box hugs its child on both axes, with uniform padding around the page.
class _PreviewShell extends StatelessWidget {
  const _PreviewShell({
    required this.child,
    this.width,
    this.height,
  });

  final Widget child;
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Center expands on the cross axis (list width) but sizes to the child
    // on the main axis, so the box can hug the page without ListView errors.
    return Center(
      child: Container(
        width: width,
        height: height,
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(LocalFilePreview.boxPadding),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: scheme.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
        alignment: Alignment.center,
        child: child,
      ),
    );
  }
}

class _ImagePreview extends StatelessWidget {
  const _ImagePreview({required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxPageWidth =
            constraints.maxWidth - LocalFilePreview.boxPadding * 2;
        return _PreviewShell(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: LocalFilePreview.pageHeight,
              maxWidth: maxPageWidth > 0 ? maxPageWidth : constraints.maxWidth,
            ),
            child: Image.file(
              File(path),
              fit: BoxFit.contain,
              gaplessPlayback: true,
              errorBuilder: (context, error, stackTrace) {
                return Text(
                  'Could not load image preview',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                );
              },
              frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                if (wasSynchronouslyLoaded || frame != null) {
                  return child;
                }
                return const SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(strokeWidth: 2),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class _PdfFirstPagePreview extends StatelessWidget {
  const _PdfFirstPagePreview({required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        return PdfDocumentViewBuilder.file(
          path,
          loadingBuilder: (context) => const _PreviewShell(
            child: SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
          errorBuilder: (context, error, stackTrace) => _PreviewShell(
            child: Text(
              'Could not load PDF preview',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
          ),
          builder: (context, document) {
            if (document == null || document.pages.isEmpty) {
              return _PreviewShell(
                child: Text(
                  'PDF has no pages',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
              );
            }

            final page = document.pages.first;
            final aspect = page.width / page.height;
            final pad = LocalFilePreview.boxPadding;
            final maxPageWidth = (constraints.maxWidth - pad * 2).clamp(
              0.0,
              double.infinity,
            );

            var pageHeight = LocalFilePreview.pageHeight;
            var pageWidth = pageHeight * aspect;
            if (pageWidth > maxPageWidth && maxPageWidth > 0) {
              pageWidth = maxPageWidth;
              pageHeight = pageWidth / aspect;
            }

            return _PreviewShell(
              width: pageWidth + pad * 2,
              height: pageHeight + pad * 2,
              child: SizedBox(
                width: pageWidth,
                height: pageHeight,
                child: PdfPageView(
                  document: document,
                  pageNumber: 1,
                  alignment: Alignment.center,
                ),
              ),
            );
          },
        );
      },
    );
  }
}
