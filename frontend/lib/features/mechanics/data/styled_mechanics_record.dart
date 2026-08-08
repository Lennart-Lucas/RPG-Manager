import 'package:flutter/material.dart';

import '../../catalog/ui/catalog_appearance.dart';

/// Shared payload shape for conditions and damage types.
class StyledMechanicsRecord {
  const StyledMechanicsRecord({
    required this.name,
    required this.description,
    this.iconKey = 'monitor_heart',
    this.colorArgb,
    this.sourceFileId,
    this.sourcePage,
  });

  final String name;
  final String description;
  final String iconKey;
  final int? colorArgb;
  final int? sourceFileId;
  final int? sourcePage;

  factory StyledMechanicsRecord.fromJson(
    Map<String, dynamic> json, {
    String defaultIconKey = 'monitor_heart',
  }) {
    return StyledMechanicsRecord(
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      iconKey: json['iconKey'] as String? ?? defaultIconKey,
      colorArgb: json['colorArgb'] as int?,
      sourceFileId: json['sourceFileId'] as int? ??
          (json['source_file_id'] as int?),
      sourcePage: json['sourcePage'] as int? ?? (json['source_page'] as int?),
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
    return StyledMechanicsRecord.fromJson(
      {
        ...payload,
        'name': payload['name'] as String? ?? name,
      },
      defaultIconKey: defaultIconKey,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'description': description,
        'iconKey': iconKey,
        if (colorArgb != null) 'colorArgb': colorArgb,
        if (sourceFileId != null) 'sourceFileId': sourceFileId,
        if (sourcePage != null) 'sourcePage': sourcePage,
      };

  StyledMechanicsRecord copyWith({
    String? name,
    String? description,
    String? iconKey,
    int? colorArgb,
    int? sourceFileId,
    int? sourcePage,
    bool clearColorArgb = false,
    bool clearSourceFileId = false,
    bool clearSourcePage = false,
  }) {
    return StyledMechanicsRecord(
      name: name ?? this.name,
      description: description ?? this.description,
      iconKey: iconKey ?? this.iconKey,
      colorArgb: clearColorArgb ? null : (colorArgb ?? this.colorArgb),
      sourceFileId:
          clearSourceFileId ? null : (sourceFileId ?? this.sourceFileId),
      sourcePage: clearSourcePage ? null : (sourcePage ?? this.sourcePage),
    );
  }

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
