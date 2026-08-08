import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_manager/features/catalog/data/catalog_kind.dart';
import 'package:rpg_manager/features/catalog/data/catalog_models.dart';
import 'package:rpg_manager/features/settings/obsidian/data/obsidian_field_map.dart';
import 'package:rpg_manager/features/settings/obsidian/data/obsidian_note_mapper.dart';
import 'package:rpg_manager/features/settings/obsidian/data/obsidian_note_parser.dart';
import 'package:rpg_manager/features/settings/obsidian/data/obsidian_section_codec.dart';

void main() {
  test('organisation exports multi-prose sections and structured frontmatter', () {
    final item = CatalogItem(
      id: 12,
      userId: 1,
      kind: CatalogKind.organisations,
      name: 'The Guild',
      payload: {
        'description': 'A powerful guild.',
        'founding': 'Founded in 100 AR.',
        'motto': 'Together.',
        'aliases': ['Guild'],
        'parentId': 3,
        'imageUrl': 'https://example.com/g.png',
      },
    );

    final notes = ObsidianNoteMapper().planAll({
      for (final k in ObsidianNoteMapper.exportKinds)
        k: k == CatalogKind.organisations ? [item] : const <CatalogItem>[],
    });
    expect(notes, hasLength(1));
    final md = notes.single.contents;

    expect(md, contains('rpg_manager_id: 12'));
    expect(md, contains('parentId: 3'));
    expect(md, contains('imageUrl:'));
    // Description is leading body (no ## Description heading).
    expect(md, isNot(contains('## Description')));
    expect(md, contains('A powerful guild.'));
    expect(md, contains('## Founding'));
    expect(md, contains('## Motto'));

    final parsed = parseObsidianNote(md);
    expect(parsed, isNotNull);
    expect(parsed!.id, 12);
    expect(parsed.kind, CatalogKind.organisations);
    expect(parsed.frontmatter['parentId'], 3);
    expect(parsed.parsedBody.sections['Description'], contains('powerful guild'));
    expect(parsed.parsedBody.sections['Founding'], contains('100 AR'));
    expect(parsed.parsedBody.sections['Motto'], contains('Together'));
  });

  test('spell higher levels round-trips as section', () {
    final map = obsidianFieldMapFor(CatalogKind.spells);
    final payload = {
      'description': 'Deal fire damage.',
      'level': 3,
      'higherLevels': {
        'description': 'Extra die.',
        'damageDiceIncrement': '1d6',
      },
    };
    final body = renderObsidianBody(
      map: map,
      payload: payload,
      rewriteLinks: (t) => t,
    );
    expect(body, isNot(contains('## Description')));
    expect(body, startsWith('Deal fire damage.'));
    expect(body, contains('## At higher levels'));
    expect(body, contains('Extra die.'));

    final fm = frontmatterPayloadSlice(map: map, payload: payload);
    expect(fm['level'], 3);
    expect(fm['higherLevels'], isA<Map>());
    expect((fm['higherLevels'] as Map)['description'], isNull);
    expect((fm['higherLevels'] as Map)['damageDiceIncrement'], '1d6');

    final parsedBody = parseObsidianBody(body, map: map);
    expect(parsedBody.sections['Description'], contains('fire damage'));
    expect(
      parsedBody.sections['At higher levels'],
      contains('Extra die'),
    );
  });

  test('legacy ## Description section still imports', () {
    final map = obsidianFieldMapFor(CatalogKind.conditions);
    final parsedBody = parseObsidianBody(
      '## Description\n\nYou cannot be seen.\n',
      map: map,
    );
    expect(parsedBody.sections['Description'], contains('cannot be seen'));
  });
}
