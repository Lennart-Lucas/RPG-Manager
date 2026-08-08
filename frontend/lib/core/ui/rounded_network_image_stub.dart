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
  required Widget Function(BuildContext, Object, StackTrace?) errorBuilder,
  required Widget Function(BuildContext) loadingBuilder,
}) {
  return ClipRRect(
    borderRadius: BorderRadius.circular(borderRadius),
    child: Image.network(
      url,
      fit: BoxFit.fitWidth,
      width: double.infinity,
      errorBuilder: errorBuilder,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return AspectRatio(
          aspectRatio: placeholderAspectRatio,
          child: loadingBuilder(context),
        );
      },
    ),
  );
}
