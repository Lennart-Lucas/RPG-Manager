class SkillRecord {
  const SkillRecord({
    required this.name,
    required this.attribute,
  });

  final String name;
  /// Ability code: STR, DEX, CON, INT, WIS, or CHA.
  final String attribute;

  static const attributes = ['STR', 'DEX', 'CON', 'INT', 'WIS', 'CHA'];

  factory SkillRecord.fromCatalogPayload({
    required String name,
    Map<String, dynamic>? payload,
  }) {
    final raw = payload?['attribute'] ?? payload?['ability'];
    final attribute = _normalizeAttribute(raw) ?? 'STR';
    return SkillRecord(name: name, attribute: attribute);
  }

  Map<String, dynamic> toJson() => {
        'attribute': attribute,
      };

  static String? _normalizeAttribute(dynamic raw) {
    if (raw is! String) return null;
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    final upper = trimmed.toUpperCase();
    if (attributes.contains(upper)) return upper;
    return switch (trimmed.toLowerCase()) {
      'str' || 'strength' => 'STR',
      'dex' || 'dexterity' => 'DEX',
      'con' || 'constitution' => 'CON',
      'int' || 'intelligence' => 'INT',
      'wis' || 'wisdom' => 'WIS',
      'cha' || 'charisma' => 'CHA',
      _ => null,
    };
  }
}
