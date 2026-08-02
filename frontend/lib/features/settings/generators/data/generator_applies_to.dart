import '../../../catalog/data/catalog_kind.dart';

/// Declares which catalog create surfaces offer this generator.
///
/// Absent/`null` means Settings-only (not listed on create FABs).
class GeneratorAppliesTo {
  const GeneratorAppliesTo({required this.kind});

  /// Target catalog kind (e.g. [CatalogKind.locations]).
  final CatalogKind kind;

  /// Whether this applies to a create surface for [targetKind].
  bool matches(CatalogKind targetKind) => kind == targetKind;

  String? validate() {
    if (kind == CatalogKind.generators) {
      return 'appliesTo.kind cannot be generators';
    }
    return null;
  }

  factory GeneratorAppliesTo.fromJson(Map<String, dynamic> json) {
    final kindRaw = '${json['kind'] ?? ''}'.trim();
    final kind = CatalogKind.tryParseApiValue(kindRaw);
    if (kind == null) {
      throw FormatException(
        'appliesTo.kind must be a catalog kind api value, got "$kindRaw"',
      );
    }
    final value = GeneratorAppliesTo(kind: kind);
    final error = value.validate();
    if (error != null) throw FormatException(error);
    return value;
  }

  /// Returns null when [json] is null/empty (generator stays Settings-only).
  ///
  /// Unknown extra keys (e.g. legacy `types`) are ignored.
  static GeneratorAppliesTo? tryParse(Object? json) {
    if (json == null) return null;
    if (json is! Map) {
      throw FormatException('appliesTo must be a JSON object');
    }
    final map = Map<String, dynamic>.from(json);
    if (map.isEmpty) return null;
    final kindRaw = '${map['kind'] ?? ''}'.trim();
    if (kindRaw.isEmpty) return null;
    return GeneratorAppliesTo.fromJson(map);
  }

  Map<String, dynamic> toJson() => {'kind': kind.apiValue};

  /// Human-readable label for lists / detail.
  String get displayLabel => kind.pluralLabel;

  /// Kinds offered in the generator authoring dropdown (create targets).
  static List<CatalogKind> get createTargetKinds => CatalogKind.values
      .where((k) => k != CatalogKind.generators)
      .toList(growable: false);
}
