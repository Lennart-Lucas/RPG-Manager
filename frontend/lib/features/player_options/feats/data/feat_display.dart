import '../../../../core/markdown/wiki_link.dart';
import '../../../../core/ui/card_text_pagination.dart';
import 'feat_model.dart';

/// Plain-text preview of markdown for list cards.
String featMarkdownPreview(String markdown) {
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

extension FeatDisplay on FeatRecord {
  bool get hasRequirement => requirement.trim().isNotEmpty;

  String? get listSubtitle {
    final preview = featMarkdownPreview(requirement);
    if (preview.isEmpty) return null;
    return preview;
  }

  String get descriptionPreview => featMarkdownPreview(description);
}
