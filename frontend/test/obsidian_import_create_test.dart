import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_manager/features/catalog/data/catalog_kind.dart';
import 'package:rpg_manager/features/catalog/data/catalog_models.dart';
import 'package:rpg_manager/features/settings/obsidian/data/obsidian_import_service.dart';
import 'package:rpg_manager/features/settings/obsidian/data/obsidian_note_mapper.dart';
import 'package:rpg_manager/features/settings/obsidian/data/obsidian_note_parser.dart';

void main() {
  group('parseObsidianNote optional id', () {
    test('parses kind-only frontmatter without id', () {
      const md = '''
---
rpg_manager_kind: "conditions"
name: "Invisible"
---

You cannot be seen.
''';
      final parsed = parseObsidianNote(md);
      expect(parsed, isNotNull);
      expect(parsed!.id, isNull);
      expect(parsed.kind, CatalogKind.conditions);
      expect(parsed.name, 'Invisible');
      expect(parsed.parsedBody.sections['Description'], contains('seen'));
    });

    test('parses id when present', () {
      const md = '''
---
rpg_manager_id: 12
rpg_manager_kind: "organisations"
name: "The Guild"
---

Body
''';
      final parsed = parseObsidianNote(md);
      expect(parsed!.id, 12);
      expect(parsed.kind, CatalogKind.organisations);
    });

    test('uses kindHint when frontmatter kind is missing', () {
      const md = '''
---
name: "Fire"
---

Hot.
''';
      final parsed = parseObsidianNote(
        md,
        kindHint: CatalogKind.damageTypes,
      );
      expect(parsed, isNotNull);
      expect(parsed!.kind, CatalogKind.damageTypes);
      expect(parsed.id, isNull);
    });

    test('plain markdown uses kindHint', () {
      final parsed = parseObsidianNote(
        'Just some text.',
        kindHint: CatalogKind.conditions,
      );
      expect(parsed, isNotNull);
      expect(parsed!.kind, CatalogKind.conditions);
      expect(parsed.body, 'Just some text.');
    });
  });

  group('inferKindFromVaultPath', () {
    test('resolves Conditions folder', () {
      expect(
        ObsidianNoteMapper.inferKindFromVaultPath(
          r'D:\vault\RPG Manager\Conditions\Invisible.md',
        ),
        CatalogKind.conditions,
      );
    });

    test('prefers Subclasses over Classes', () {
      expect(
        ObsidianNoteMapper.inferKindFromVaultPath(
          '/vault/RPG Manager/Classes/Wizard/Subclasses/Evocation.md',
        ),
        CatalogKind.subclasses,
      );
    });

    test('resolves Sessions under Campaigns', () {
      expect(
        ObsidianNoteMapper.inferKindFromVaultPath(
          '/vault/RPG Manager/Campaigns/Main/Sessions/Session 1.md',
        ),
        CatalogKind.sessions,
      );
    });
  });

  group('nameFromFilePath', () {
    test('strips extension and id suffix', () {
      expect(
        ObsidianNoteMapper.nameFromFilePath(
          r'D:\vault\RPG Manager\Conditions\Invisible (42).md',
        ),
        'Invisible',
      );
    });
  });

  group('writeObsidianSystemFrontmatter', () {
    test('inserts system keys into existing frontmatter', () {
      const md = '''
---
parentId: 3
name: "Old"
---

## Description

Hello
''';
      final out = writeObsidianSystemFrontmatter(
        md,
        id: 99,
        kind: CatalogKind.organisations,
        name: 'The Guild',
      );
      expect(out, contains('rpg_manager_id: 99'));
      expect(out, contains('rpg_manager_kind: "organisations"'));
      expect(out, contains('name: "The Guild"'));
      expect(out, contains('parentId: 3'));
      expect(out, contains('## Description'));
      expect(out, contains('Hello'));
    });

    test('prepends frontmatter when missing', () {
      final out = writeObsidianSystemFrontmatter(
        'Body only.',
        id: 5,
        kind: CatalogKind.conditions,
        name: 'Blinded',
      );
      expect(out, startsWith('---'));
      expect(out, contains('rpg_manager_id: 5'));
      expect(out, contains('Body only.'));
    });
  });

  group('summarizeObsidianImportBatch', () {
    CatalogItem item(int id, String name) => CatalogItem(
          id: id,
          userId: 1,
          kind: CatalogKind.conditions,
          name: name,
          payload: const {},
        );

    test('counts created and updated', () {
      final batch = ObsidianImportBatchResult(
        outcomes: [
          ObsidianImportFileOutcome(
            path: 'a.md',
            result: ObsidianImportResult(
              item: item(1, 'A'),
              name: 'A',
              kind: CatalogKind.conditions,
              created: false,
            ),
          ),
          ObsidianImportFileOutcome(
            path: 'b.md',
            result: ObsidianImportResult(
              item: item(2, 'B'),
              name: 'B',
              kind: CatalogKind.conditions,
              created: true,
            ),
          ),
          const ObsidianImportFileOutcome(
            path: 'c.md',
            error: 'bad note',
          ),
        ],
      );
      expect(
        batch.summary,
        'Imported 2 (1 updated, 1 created); 1 failed (bad note)',
      );
    });
  });
}
