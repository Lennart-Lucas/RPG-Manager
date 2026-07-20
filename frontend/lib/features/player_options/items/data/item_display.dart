import '../../../../core/markdown/wiki_link.dart';
import 'item_model.dart';

/// Plain-text preview of item description markdown for list cards.
String itemDescriptionPreview(String description) {
  var t = description.trim();
  if (t.isEmpty) return '';

  t = t.replaceAllMapped(wikiLinkPattern, (match) {
    final alias = match.group(3)?.trim();
    final name = match.group(2)?.trim() ?? '';
    if (alias != null && alias.isNotEmpty) return alias;
    return name;
  });
  t = t.replaceAll(RegExp(r'^\s*\|?\s*:?-{3,}:?\s*(\|\s*:?-{3,}:?\s*)+\|?\s*$',
      multiLine: true), ' ');
  t = t.replaceAll('|', ' ');
  t = t.replaceAll(RegExp(r'</?u>', caseSensitive: false), '');
  t = t.replaceAll(RegExp(r'^#{1,6}\s+', multiLine: true), '');
  t = t.replaceAll(RegExp(r'^\s*[-*]\s+', multiLine: true), '');
  t = t.replaceAll(RegExp(r'^\s*\d+\.\s+', multiLine: true), '');
  t = t.replaceAll(RegExp(r'\*\*\*|___|\*\*|__|\*|_|`'), '');
  t = t.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (t.isEmpty) return '';
  if (t.length <= 220) return t;
  return '${t.substring(0, 217)}…';
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
