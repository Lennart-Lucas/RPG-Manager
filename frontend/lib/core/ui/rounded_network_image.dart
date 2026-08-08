import 'package:flutter/widgets.dart';

import 'rounded_network_image_stub.dart'
    if (dart.library.js_interop) 'rounded_network_image_web.dart' as impl;

/// Network image with reliable corner rounding on every platform.
///
/// On web, Flutter's HTML `<img>` platform views ignore [ClipRRect], so the
/// web implementation applies CSS `border-radius` instead.
Widget roundedNetworkImage({
  required String url,
  required double borderRadius,
  required Widget Function(BuildContext, Object, StackTrace?) errorBuilder,
  BoxFit fit = BoxFit.cover,
  Alignment alignment = Alignment.center,
  double? width,
  double? height,
  ImageLoadingBuilder? loadingBuilder,
}) {
  return impl.buildRoundedNetworkImage(
    url: url,
    borderRadius: borderRadius,
    errorBuilder: errorBuilder,
    fit: fit,
    alignment: alignment,
    width: width,
    height: height,
    loadingBuilder: loadingBuilder,
  );
}

/// Full-width image whose height follows the intrinsic aspect ratio.
Widget roundedFitWidthNetworkImage({
  required String url,
  required double borderRadius,
  required double placeholderAspectRatio,
  required Widget Function(BuildContext, Object, StackTrace?) errorBuilder,
  required Widget Function(BuildContext) loadingBuilder,
}) {
  return impl.buildRoundedFitWidthNetworkImage(
    url: url,
    borderRadius: borderRadius,
    placeholderAspectRatio: placeholderAspectRatio,
    errorBuilder: errorBuilder,
    loadingBuilder: loadingBuilder,
  );
}
