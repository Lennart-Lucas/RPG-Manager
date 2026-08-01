import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_manager/core/ui/card_text_pagination.dart';

void main() {
  test('prefers paragraph breaks over mid-sentence splits', () {
    final para1 = 'A' * 400;
    final para2 = 'B' * 400;
    final para3 = 'C' * 400;
    final text = '$para1\n\n$para2\n\n$para3';
    final pages = paginateCardBodyText(
      text,
      preferredCharsPerCard: 500,
      maxCharsPerCard: 900,
    );
    expect(pages.length, greaterThan(1));
    for (final page in pages) {
      expect(page.contains('A') && page.contains('B') && page.contains('C'), isFalse);
    }
    expect(pages.first.endsWith('A'), isTrue);
  });

  test('does not split inside bold markdown', () {
    final before = 'Word ' * 180; // ~900 chars
    const bold = '**important phrase**';
    final after = ' tail ' * 80;
    final text = '$before$bold$after';
    final pages = paginateCardBodyText(
      text,
      preferredCharsPerCard: before.length + 8,
      maxCharsPerCard: before.length + bold.length + 40,
    );
    final joined = pages.join('');
    expect(joined.contains('**important phrase**'), isTrue);
    for (final page in pages) {
      final opens = '**'.allMatches(page).length;
      expect(opens.isEven, isTrue, reason: 'page should not split a ** pair: $page');
    }
  });

  test('explicit card-break marker forces a new card', () {
    const text = 'First card body.\n$kCardBreakMarker\nSecond card body.';
    final pages = paginateCardBodyText(
      text,
      preferredCharsPerCard: 900,
      maxCharsPerCard: 1300,
    );
    expect(pages, ['First card body.', 'Second card body.']);
    for (final page in pages) {
      expect(page.contains(kCardBreakMarker), isFalse);
    }
  });

  test('stripCardBreakMarkers removes markers for display', () {
    expect(
      stripCardBreakMarkers('Hello\n$kCardBreakMarker\nWorld'),
      'Hello\n\nWorld',
    );
  });
}
