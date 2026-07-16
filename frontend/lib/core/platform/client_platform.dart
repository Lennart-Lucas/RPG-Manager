import 'package:flutter/foundation.dart';

/// Values must match backend `ClientPlatform` enum.
enum ClientPlatform {
  desktop,
  web,
  android,
  ios;

  String get apiValue => name;
}

ClientPlatform detectClientPlatform() {
  if (kIsWeb) {
    return ClientPlatform.web;
  }
  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
      return ClientPlatform.android;
    case TargetPlatform.iOS:
      return ClientPlatform.ios;
    case TargetPlatform.windows:
    case TargetPlatform.linux:
    case TargetPlatform.macOS:
      return ClientPlatform.desktop;
    default:
      return ClientPlatform.web;
  }
}
