class RuleRecord {
  const RuleRecord({
    required this.name,
    this.parentRuleId,
    this.body = '',
  });

  final String name;
  final int? parentRuleId;
  final String body;

  factory RuleRecord.fromJson(Map<String, dynamic> json) {
    return RuleRecord(
      name: json['name'] as String? ?? '',
      parentRuleId: (json['parentRuleId'] as num?)?.toInt(),
      body: json['body'] as String? ?? '',
    );
  }

  factory RuleRecord.fromCatalogPayload({
    required String name,
    Map<String, dynamic>? payload,
  }) {
    if (payload == null) {
      return RuleRecord(name: name);
    }
    return RuleRecord(
      name: payload['name'] as String? ?? name,
      parentRuleId: (payload['parentRuleId'] as num?)?.toInt(),
      body: payload['body'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        if (parentRuleId != null) 'parentRuleId': parentRuleId,
        'body': body,
      };

  RuleRecord copyWith({
    String? name,
    int? parentRuleId,
    String? body,
    bool clearParentRuleId = false,
  }) {
    return RuleRecord(
      name: name ?? this.name,
      parentRuleId:
          clearParentRuleId ? null : (parentRuleId ?? this.parentRuleId),
      body: body ?? this.body,
    );
  }
}
