import 'model/generated_record.dart';

/// Pluggable conversion from [GeneratedRecord] to domain objects.
class RecordFactoryRegistry {
  final Map<String, Object Function(GeneratedRecord)> _builders = {};

  void register(String type, Object Function(GeneratedRecord) builder) {
    _builders[type] = builder;
  }

  bool isRegistered(String type) => _builders.containsKey(type);

  Object build(GeneratedRecord record) {
    final builder = _builders[record.type];
    if (builder == null) {
      throw StateError(
        'No RecordFactory builder registered for type "${record.type}"',
      );
    }
    return builder(record);
  }
}
