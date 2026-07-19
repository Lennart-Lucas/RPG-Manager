import 'dart:convert';

import 'package:flutter/services.dart';

class MonstrousTrait {
  const MonstrousTrait({
    required this.id,
    required this.category,
    required this.keywords,
    required this.name,
    required this.description,
    this.parameters = const [],
  });

  final String id;
  final String category;
  final List<String> keywords;
  final String name;
  final String description;
  final List<String> parameters;

  factory MonstrousTrait.fromJson(Map<String, dynamic> json) {
    return MonstrousTrait(
      id: json['id'] as String? ?? '',
      category: json['category'] as String? ?? '',
      keywords: [
        for (final k in (json['keywords'] as List?) ?? const []) '$k',
      ],
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      parameters: [
        for (final p in (json['parameters'] as List?) ?? const []) '$p',
      ],
    );
  }

  String filledDescription(Map<String, String> values) {
    var text = description;
    for (final key in parameters) {
      final value = values[key]?.trim();
      if (value != null && value.isNotEmpty) {
        text = text.replaceAll('{$key}', value);
      }
    }
    return text;
  }
}

class MonstrousTraitsCatalog {
  MonstrousTraitsCatalog._(this.traits);

  final List<MonstrousTrait> traits;

  static MonstrousTraitsCatalog? _instance;

  static Future<MonstrousTraitsCatalog> load() async {
    if (_instance != null) return _instance!;
    final raw =
        await rootBundle.loadString('assets/data/monstrous_traits.json');
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final list = (json['traits'] as List?) ?? const [];
    final traits = [
      for (final item in list)
        if (item is Map<String, dynamic>) MonstrousTrait.fromJson(item),
    ];
    return _instance = MonstrousTraitsCatalog._(traits);
  }

  List<String> get categories {
    final set = <String>{};
    for (final t in traits) {
      if (t.category.isNotEmpty) set.add(t.category);
    }
    final out = set.toList()..sort();
    return out;
  }

  List<MonstrousTrait> filter({String? category, String query = ''}) {
    final q = query.trim().toLowerCase();
    return [
      for (final t in traits)
        if ((category == null || category.isEmpty || t.category == category) &&
            (q.isEmpty ||
                t.name.toLowerCase().contains(q) ||
                t.description.toLowerCase().contains(q) ||
                t.keywords.any((k) => k.toLowerCase().contains(q))))
          t,
    ];
  }
}
