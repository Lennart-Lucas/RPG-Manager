import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Device-local Anthropic API key. Not cleared on auth logout.
class AnthropicKeyStore {
  AnthropicKeyStore({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              mOptions: MacOsOptions(useDataProtectionKeyChain: false),
            );

  static const _key = 'anthropic_api_key';

  final FlutterSecureStorage _storage;

  Future<void> save(String apiKey) async {
    final trimmed = apiKey.trim();
    if (trimmed.isEmpty) {
      await clear();
      return;
    }
    await _storage.write(key: _key, value: trimmed);
  }

  Future<String?> read() => _storage.read(key: _key);

  Future<bool> hasKey() async {
    final value = await read();
    return value != null && value.trim().isNotEmpty;
  }

  Future<void> clear() async {
    await _storage.delete(key: _key);
  }

  /// Masked preview for Preferences (e.g. sk-ant-…abcd).
  Future<String?> maskedPreview() async {
    final value = await read();
    if (value == null || value.trim().isEmpty) return null;
    final key = value.trim();
    if (key.length <= 8) return '••••••••';
    return '${key.substring(0, 7)}…${key.substring(key.length - 4)}';
  }
}
