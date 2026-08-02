import '../../../catalog/data/catalog_api.dart';
import '../../../catalog/data/catalog_kind.dart';
import '../../../catalog/data/catalog_models.dart';
import 'generator_model.dart';

/// A generator catalog row ready for create-surface matching.
class GeneratorCreateEntry {
  const GeneratorCreateEntry({
    required this.item,
    required this.record,
  });

  final CatalogItem item;
  final GeneratorRecord record;

  String get name =>
      record.name.trim().isNotEmpty ? record.name.trim() : item.name;

  String get subtitle => 'Type: ${record.recordTypeLabel}';
}

/// Loads generators and filters those offered for a catalog create surface.
class GeneratorCreateIndex {
  GeneratorCreateIndex({CatalogApi? api}) : _api = api ?? CatalogApi();

  final CatalogApi _api;

  /// Generators with `appliesTo` matching [kind], sorted by name.
  Future<List<GeneratorCreateEntry>> listForCreate({
    required String accessToken,
    required CatalogKind kind,
  }) async {
    final items = await _api.list(accessToken, CatalogKind.generators);
    final entries = <GeneratorCreateEntry>[];
    for (final item in items) {
      final record = GeneratorRecord.fromCatalogPayload(
        name: item.name,
        payload: item.payload,
      );
      final applies = record.appliesTo;
      if (applies == null) continue;
      if (!applies.matches(kind)) continue;
      entries.add(GeneratorCreateEntry(item: item, record: record));
    }
    entries.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );
    return entries;
  }
}
