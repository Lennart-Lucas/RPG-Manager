import 'package:flutter_test/flutter_test.dart';
import 'package:random_table_engine/generation_engine.dart';
import 'package:rpg_manager/features/catalog/data/catalog_kind.dart';
import 'package:rpg_manager/features/settings/generators/data/generator_record_mapping.dart';

void main() {
  group('GeneratorRecordMapping', () {
    test('parses bindings and validates kinds', () {
      final mapping = GeneratorRecordMapping.fromJson({
        'version': 1,
        'bindings': [
          {
            'matchType': 'settlement',
            'kind': 'locations',
            'nameFrom': 'name',
            'fields': [
              {'to': 'name', 'from': 'name'},
              {'to': 'type', 'literal': 'settlement'},
            ],
          },
        ],
      });
      expect(mapping.version, 1);
      expect(mapping.bindings, hasLength(1));
      expect(mapping.bindings.first.kind, CatalogKind.locations);
      expect(mapping.validate(), isNull);
    });

    test('rejects unknown kind', () {
      expect(
        () => GeneratorRecordMapping.fromJson({
          'bindings': [
            {
              'matchType': 'x',
              'kind': 'not_a_kind',
              'nameFrom': 'name',
              'fields': [
                {'to': 'name', 'from': 'name'},
              ],
            },
          ],
        }),
        throwsFormatException,
      );
    });

    test('concats from list with newlines', () {
      final mapping = GeneratorRecordMapping.fromJson({
        'bindings': [
          {
            'matchType': 'settlement',
            'kind': 'locations',
            'nameFrom': 'name',
            'fields': [
              {'to': 'name', 'from': 'name'},
              {
                'to': 'description',
                'from': ['history', 'defenses'],
                'join': '\n',
              },
            ],
          },
        ],
      });
      final record = GeneratedRecord(
        id: '1',
        type: 'settlement',
        fields: {
          'name': 'Riverton',
          'history': 'Old ferry town.',
          'defenses': 'Wooden palisade.',
        },
      );
      final created = mapping.buildCreate(
        record: record,
        allRecords: [record],
      );
      expect(created.name, 'Riverton');
      expect(created.payload['description'], 'Old ferry town.\nWooden palisade.');
    });

    test('fromChildren concats matching parentField', () {
      final mapping = GeneratorRecordMapping.fromJson({
        'bindings': [
          {
            'matchType': 'settlement',
            'kind': 'locations',
            'nameFrom': 'name',
            'fields': [
              {'to': 'name', 'from': 'name'},
              {
                'to': 'mapNotes',
                'fromChildren': {
                  'parentField': 'shops',
                  'from': 'value',
                },
              },
            ],
          },
        ],
      });
      final root = GeneratedRecord(
        id: 'root',
        type: 'settlement',
        fields: {'name': 'Riverton'},
      );
      final shopA = GeneratedRecord(
        id: 'a',
        type: 'shop',
        parentId: 'root',
        parentField: 'shops',
        fields: {'value': 'Baker'},
      );
      final shopB = GeneratedRecord(
        id: 'b',
        type: 'shop',
        parentId: 'root',
        parentField: 'shops',
        fields: {'value': 'Smith'},
      );
      final note = GeneratedRecord(
        id: 'c',
        type: 'note',
        parentId: 'root',
        parentField: 'notes',
        fields: {'value': 'ignored'},
      );
      final created = mapping.buildCreate(
        record: root,
        allRecords: [root, shopA, shopB, note],
      );
      expect(created.payload['mapNotes'], 'Baker\nSmith');
    });

    test('link remaps generated parent to catalog id', () {
      final mapping = GeneratorRecordMapping.fromJson({
        'bindings': [
          {
            'matchType': 'shop',
            'kind': 'locations',
            'nameFrom': 'name',
            'link': {'to': 'parentId'},
            'fields': [
              {'to': 'name', 'from': 'name'},
              {'to': 'type', 'literal': 'site'},
            ],
          },
        ],
      });
      final shop = GeneratedRecord(
        id: 'shop1',
        type: 'shop',
        parentId: 'settlement1',
        parentField: 'shops',
        fields: {'name': 'Baker'},
      );
      final created = mapping.buildCreate(
        record: shop,
        allRecords: [shop],
        catalogIdByGenId: {'settlement1': 42},
      );
      expect(created.payload['parentId'], 42);
      expect(created.payload['type'], 'site');
    });

    test('recordsToApplyInOrder is parent-first and skips unmapped', () {
      final mapping = GeneratorRecordMapping.fromJson({
        'bindings': [
          {
            'matchType': 'settlement',
            'kind': 'locations',
            'nameFrom': 'name',
            'fields': [
              {'to': 'name', 'from': 'name'},
            ],
          },
          {
            'matchType': 'shop',
            'kind': 'locations',
            'nameFrom': 'name',
            'link': {'to': 'parentId'},
            'fields': [
              {'to': 'name', 'from': 'name'},
            ],
          },
        ],
      });
      final root = GeneratedRecord(
        id: 'root',
        type: 'settlement',
        fields: {'name': 'Town'},
      );
      final shop = GeneratedRecord(
        id: 'shop',
        type: 'shop',
        parentId: 'root',
        fields: {'name': 'Baker'},
      );
      final orphan = GeneratedRecord(
        id: 'note',
        type: 'note',
        parentId: 'root',
        fields: {'text': 'x'},
      );
      final ordered = recordsToApplyInOrder(
        records: [shop, orphan, root],
        mapping: mapping,
      );
      expect(ordered.map((r) => r.id).toList(), ['root', 'shop']);
    });

    test('needsExternalParent when root has link and no gen parent', () {
      final mapping = GeneratorRecordMapping.fromJson({
        'bindings': [
          {
            'matchType': 'site',
            'kind': 'locations',
            'nameFrom': 'name',
            'link': {'to': 'parentId'},
            'fields': [
              {'to': 'name', 'from': 'name'},
            ],
          },
        ],
      });
      final root = GeneratedRecord(
        id: '1',
        type: 'site',
        fields: {'name': 'Cave'},
      );
      expect(mapping.needsExternalParent(root), isTrue);
      expect(
        mapping.externalParentPickerKind(root),
        CatalogKind.locations,
      );
    });

    test('locations matchType city aliases to settlement root', () {
      final mapping = GeneratorRecordMapping.fromJson({
        'bindings': [
          {
            'matchType': 'city',
            'kind': 'locations',
            'nameFrom': 'name',
            'fields': [
              {'to': 'name', 'from': 'name'},
              {
                'to': 'description',
                'from': ['age', 'size'],
                'join': '\n',
              },
            ],
          },
        ],
      });
      final root = GeneratedRecord(
        id: 'root',
        type: 'settlement',
        fields: {
          'name': 'Riverton',
          'age': 'Old',
          'size': 'Large',
        },
      );
      final shop = GeneratedRecord(
        id: 's1',
        type: 'shop',
        parentId: 'root',
        parentField: 'shops',
        fields: {'value': 'Baker'},
      );
      final ordered = recordsToApplyInOrder(
        records: [root, shop],
        mapping: mapping,
        processRecordType: 'settlement',
      );
      expect(ordered.map((r) => r.id).toList(), ['root']);
      final created = mapping.buildCreate(
        record: root,
        allRecords: [root, shop],
        processRecordType: 'settlement',
      );
      expect(created.payload['type'], 'city');
      expect(created.payload['description'], 'Old\nLarge');
    });

    test('buildApplyPlan marks creates, folds, and skips', () {
      final mapping = GeneratorRecordMapping.fromJson({
        'bindings': [
          {
            'matchType': 'settlement',
            'kind': 'locations',
            'nameFrom': 'name',
            'fields': [
              {'to': 'name', 'from': 'name'},
              {
                'to': 'mapNotes',
                'fromChildren': {'parentField': 'shops', 'from': 'value'},
              },
            ],
          },
        ],
      });
      final root = GeneratedRecord(
        id: 'root',
        type: 'settlement',
        fields: {'name': 'Town'},
      );
      final shop = GeneratedRecord(
        id: 's1',
        type: 'shop',
        parentId: 'root',
        parentField: 'shops',
        fields: {'value': 'Baker'},
      );
      final note = GeneratedRecord(
        id: 'n1',
        type: 'note',
        parentId: 'root',
        parentField: 'notes',
        fields: {'text': 'x'},
      );
      final plan = mapping.buildApplyPlan(
        records: [root, shop, note],
        processRecordType: 'settlement',
      );
      expect(plan[0].willCreate, isTrue);
      expect(plan[0].name, 'Town');
      expect(plan[1].fate, GeneratorApplyFate.skipped);
      expect(plan[1].detail, contains('fromChildren'));
      expect(plan[2].detail, contains('no binding'));
    });
  });
}
