import '../../../../core/markdown/wiki_link.dart';
import '../../../../core/ui/card_text_pagination.dart';
import 'item_property_model.dart';

/// Plain-text preview of markdown for list cards.
String itemPropertyMarkdownPreview(String markdown) {
  var t = stripCardBreakMarkers(markdown);
  if (t.isEmpty) return '';

  t = stripWikiMarkup(t);
  t = t.replaceAll(
    RegExp(
      r'^\s*\|?\s*:?-{3,}:?\s*(\|\s*:?-{3,}:?\s*)+\|?\s*$',
      multiLine: true,
    ),
    ' ',
  );
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

extension ItemPropertyDisplay on ItemPropertyRecord {
  String get descriptionPreview => itemPropertyMarkdownPreview(description);
}
