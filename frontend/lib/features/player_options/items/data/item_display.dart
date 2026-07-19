import 'item_model.dart';

String itemDescriptionPreview(String description) {
  final t = description.trim();
  if (t.isEmpty) return '';
  final oneLine = t.replaceAll(RegExp(r'\s+'), ' ');
  if (oneLine.length <= 80) return oneLine;
  return '${oneLine.substring(0, 77)}…';
}

extension ItemDisplay on Item {
  List<String> get listSubtitleFlags {
    return [
      if (magic) 'Magic',
      if (requiresAttunement) 'Attunement',
      if (consumable) 'Consumable',
    ];
  }

  String get listSubtitle {
    final parts = <String>[rarity.label, ...listSubtitleFlags];
    return parts.join(' · ');
  }

  String get detailsColumn {
    final ref = typeReference.trim();
    if (ref.isNotEmpty) return ref;
    final flags = listSubtitleFlags;
    return flags.isEmpty ? '—' : flags.join(' · ');
  }
}
