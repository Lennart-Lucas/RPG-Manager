import 'class_model.dart';

class SubclassRecord {
  const SubclassRecord({
    required this.name,
    required this.parentClassId,
    this.description = '',
    this.featuresByLevel = const {},
  });

  final String name;
  final int parentClassId;
  final String description;
  final Map<int, List<ClassFeature>> featuresByLevel;

  List<ClassFeature> get allFeatures {
    final levels = featuresByLevel.keys.toList()..sort();
    return [
      for (final lvl in levels) ...?featuresByLevel[lvl],
    ];
  }

  factory SubclassRecord.fromJson(Map<String, dynamic> json) {
    return SubclassRecord.fromCatalogPayload(
      name: json['name'] as String? ?? '',
      payload: json,
    );
  }

  factory SubclassRecord.fromCatalogPayload({
    required String name,
    Map<String, dynamic>? payload,
  }) {
    if (payload == null) {
      return SubclassRecord(name: name, parentClassId: 0);
    }
    return SubclassRecord(
      name: payload['name'] as String? ?? name,
      parentClassId: (payload['parentClassId'] as num?)?.toInt() ?? 0,
      description: payload['description'] as String? ?? '',
      featuresByLevel: featuresByLevelFromJson(payload['featuresByLevel']),
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'parentClassId': parentClassId,
        'description': description,
        'featuresByLevel': featuresByLevelToJson(featuresByLevel),
      };

  SubclassRecord copyWith({
    String? name,
    int? parentClassId,
    String? description,
    Map<int, List<ClassFeature>>? featuresByLevel,
  }) {
    return SubclassRecord(
      name: name ?? this.name,
      parentClassId: parentClassId ?? this.parentClassId,
      description: description ?? this.description,
      featuresByLevel: featuresByLevel ?? this.featuresByLevel,
    );
  }
}
