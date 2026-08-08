import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_manager/core/markdown/wiki_link.dart';
import 'package:rpg_manager/features/settings/obsidian/data/obsidian_note_mapper.dart';
import 'package:rpg_manager/features/settings/obsidian/data/obsidian_note_parser.dart';

void main() {
  group('wiki_link id format', () {
    test('parses kind/id and optional alias', () {
      final links = parseWikiLinks(
        'See [[conditions/42]] and [[damage_types/7|Fire]].',
      );
      expect(links, hasLength(2));
      expect(links[0].kind, 'conditions');
      expect(links[0].id, '42');
      expect(links[0].numericId, 42);
      expect(links[0].hasAlias, isFalse);
      expect(links[1].id, '7');
      expect(links[1].alias, 'Fire');
      expect(links[1].displayText, 'Fire');
    });

    test('formatWikiLink writes kind/id', () {
      expect(
        formatWikiLink(kind: 'spells', id: '9'),
        '[[spells/9]]',
      );
      expect(
        formatWikiLink(kind: 'spells', id: '9', alias: 'Fireball', embed: true),
        '![[spells/9|Fireball]]',
      );
    });

    test('autoLinkCatalogNames inserts kind/id', () {
      final linked = autoLinkCatalogNames(
        'Deal Fire damage.',
        targets: const [
          (kind: 'damage_types', id: '3', name: 'Fire'),
        ],
      );
      expect(linked, 'Deal [[damage_types/3]] damage.');
    });
  });

  group('obsidian wiki rewrite by id', () {
    test('export rewrites kind/id to vault path', () {
      final out = rewriteWikiLinksForObsidian(
        'See [[conditions/42|Invisible]].',
        linkTargets: {
          'conditions\u000042': 'RPG Manager/Conditions/Invisible',
        },
      );
      expect(out, 'See [[RPG Manager/Conditions/Invisible|Invisible]].');
    });

    test('import rewrites vault path to kind/id', () {
      final out = rewriteWikiLinksFromObsidian(
        'See [[RPG Manager/Conditions/Invisible]] and [[conditions/Invisible]].',
        targetsByWikiPath: {
          'rpg manager/conditions/invisible': (
            kind: 'conditions',
            id: 42,
          ),
        },
        idsByKindName: {
          'conditions\u0000invisible': 42,
        },
      );
      expect(
        out,
        'See [[conditions/42]] and [[conditions/42]].',
      );
    });

    test('import leaves already-id links alone', () {
      final out = rewriteWikiLinksFromObsidian(
        '[[conditions/42|X]]',
        targetsByWikiPath: const {},
      );
      expect(out, '[[conditions/42|X]]');
    });
  });
}
