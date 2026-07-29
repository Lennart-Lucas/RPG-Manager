import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// On-device OCR via Apple Vision (macOS only).
class VisionOcr {
  VisionOcr._();

  static const _channel = MethodChannel('rpg_manager/vision_ocr');

  static bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.macOS;

  static Future<bool> isAvailable() async {
    if (!isSupported) return false;
    try {
      final value = await _channel.invokeMethod<bool>('isAvailable');
      return value ?? true;
    } catch (_) {
      return false;
    }
  }

  /// Recognizes text from raw BGRA8888 pixels (same layout as [PdfImage.pixels]).
  static Future<String> recognizeBgra({
    required Uint8List pixels,
    required int width,
    required int height,
  }) async {
    if (!isSupported) {
      throw UnsupportedError('Vision OCR is only available on macOS');
    }
    final result = await _channel.invokeMethod<String>('recognizeText', {
      'pixels': pixels,
      'width': width,
      'height': height,
    });
    return result ?? '';
  }
}
