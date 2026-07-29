import 'package:flutter/material.dart';

import '../../catalog/ui/catalog_appearance.dart';

/// Shared payload shape for conditions and damage types.
class StyledMechanicsRecord {
  const StyledMechanicsRecord({
    required this.name,
    required this.description,
    this.iconKey = 'monitor_heart',
    this.colorArgb,
  });

  final String name;
  final String description;
  final String iconKey;
  final int? colorArgb;

  factory StyledMechanicsRecord.fromJson(
    Map<String, dynamic> json, {
    String defaultIconKey = 'monitor_heart',
  }) {
    return StyledMechanicsRecord(
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      iconKey: json['iconKey'] as String? ?? defaultIconKey,
      colorArgb: json['colorArgb'] as int?,
    );
  }

  factory StyledMechanicsRecord.fromCatalogPayload({
    required String name,
    Map<String, dynamic>? payload,
    String defaultIconKey = 'monitor_heart',
  }) {
    if (payload == null) {
      return StyledMechanicsRecord(name: name, description: '', iconKey: defaultIconKey);
    }
    return StyledMechanicsRecord(
      name: payload['name'] as String? ?? name,
      description: payload['description'] as String? ?? '',
      iconKey: payload['iconKey'] as String? ?? defaultIconKey,
      colorArgb: payload['colorArgb'] as int?,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'description': description,
        'iconKey': iconKey,
        if (colorArgb != null) 'colorArgb': colorArgb,
      };

  IconData resolvedIcon({required IconData fallback}) =>
      catalogAppearanceIcon(iconKey, fallback: fallback);

  Color resolvedColor({required Color fallback}) =>
      catalogAppearanceColor(colorArgb, fallback: fallback);

  String get descriptionPreview {
    final plain = description
        .replaceAll(RegExp(r'\[\[([^\]|/]+)/([^\]|]+)(?:\|([^\]]+))?\]\]'), r'$3')
        .replaceAll(RegExp(r'\[\[([^\]|/]+)/([^\]|]+)\]\]'), r'$2')
        .replaceAll(RegExp(r'[*_#>`]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (plain.length <= 140) return plain;
    return '${plain.substring(0, 137)}…';
  }
}
