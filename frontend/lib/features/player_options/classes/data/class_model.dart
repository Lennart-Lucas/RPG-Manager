class ClassRecord {
  const ClassRecord({
    required this.name,
    required this.isCaster,
  });

  final String name;
  final bool isCaster;

  factory ClassRecord.fromJson(Map<String, dynamic> json) {
    return ClassRecord(
      name: json['name'] as String? ?? '',
      isCaster: json['isCaster'] as bool? ?? false,
    );
  }

  factory ClassRecord.fromCatalogPayload({
    required String name,
    Map<String, dynamic>? payload,
  }) {
    if (payload == null) {
      return ClassRecord(name: name, isCaster: false);
    }
    return ClassRecord(
      name: payload['name'] as String? ?? name,
      isCaster: payload['isCaster'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'isCaster': isCaster,
      };
}
