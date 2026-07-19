import 'dart:convert';
import 'dart:io';

import 'package:random_table_engine/generation_engine.dart';
import 'package:test/test.dart';

class _ThrowingRoller extends Roller {
  @override
  int roll(int sides) => throw StateError('roll should not be called');
}

void main() {
  group('ProcessStep.fromJson', () {
    test('parses all five ops', () {
      expect(
        ProcessStep.fromJson({
          'op': 'roll',
          'table': 't',
          'field': 'f',
        }),
        isA<RollStep>(),
      );
      expect(
        ProcessStep.fromJson({
          'op': 'lookup',
          'table': 't',
          'keyField': 'k',
          'field': 'f',
        }),
        isA<LookupStep>(),
      );
      expect(
        ProcessStep.fromJson({
          'op': 'rollMany',
          'table': 't',
          'countField': 'c',
        }),
        isA<RollManyStep>(),
      );
      expect(
        ProcessStep.fromJson({
          'op': 'gate',
          'table': 't',
          'proceedValue': 'yes',
          'then': [],
        }),
        isA<GateStep>(),
      );
      expect(
        ProcessStep.fromJson({
          'op': 'addDefaultRecord',
          'emitAs': 'note',
        }),
        isA<AddDefaultRecordStep>(),
      );
    });

    test('unknown op throws at parse time', () {
      expect(
        () => ProcessStep.fromJson({'op': 'explode'}),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('explode'),
          ),
        ),
      );
    });
  });

  group('ProcessRunner', () {
    late TableRegistry registry;
    late GenerationProcess process;

    setUp(() {
      registry = TableRegistry.fromJson(
        jsonDecode(
          File('test/fixtures/process_tables.json').readAsStringSync(),
        ) as Map<String, dynamic>,
      );
      process = GenerationProcess.fromJson(
        jsonDecode(
          File('test/fixtures/process.json').readAsStringSync(),
        ) as Map<String, dynamic>,
      );
    });

    test('full integration is deterministic', () {
      final runner = ProcessRunner(
        registry: registry,
        roller: SeededRoller([1, 3, 1, 1, 2, 1, 1]),
        idGenerator: SequentialIdGenerator(),
      );
      final records = runner.run(process);
      expect(records.first.type, 'settlement');
      expect(records.first.fields['origin'], 'north');
      expect(records.first.fields['wealthRoll'], 3);
      expect(records.first.fields['shopCount'], '2');

      final shops =
          records.where((r) => r.type == 'shop').toList(growable: false);
      expect(shops.length, 2);
      expect(shops.every((s) => s.parentId == records.first.id), isTrue);
      expect(shops.every((s) => s.parentField == 'shops'), isTrue);
      expect(shops.map((s) => s.fields['name']).toList(), ['baker', 'smith']);

      final temples =
          records.where((r) => r.type == 'temple').toList(growable: false);
      expect(temples.length, 1);
      expect(temples.single.fields['size'], 'modest');
      expect(temples.single.parentId, records.first.id);

      final notes =
          records.where((r) => r.type == 'note').toList(growable: false);
      expect(notes.single.fields['text'], 'generated');
      expect(records.first.fields[GeneratedRecord.modifiersField], isA<Map>());
      expect(
        records.first.fields[GeneratedRecord.rollsField],
        isA<Map>(),
      );
      final originRoll =
          (records.first.fields[GeneratedRecord.rollsField] as Map)['origin'];
      expect(originRoll, isA<Map>());
      expect((originRoll as Map)['roll'], isNotNull);
      expect(originRoll['total'], isNotNull);
    });

    test('gate skip omits child', () {
      final runner = ProcessRunner(
        registry: registry,
        // origin north, wealth 3, shopCount 2, shops a/b, temple NO
        roller: SeededRoller([1, 3, 1, 1, 2, 2]),
        idGenerator: SequentialIdGenerator(),
      );
      final records = runner.run(process);
      expect(records.any((r) => r.type == 'temple'), isFalse);
    });

    test('overrides skip rolling', () {
      final runner = ProcessRunner(
        registry: registry,
        roller: _ThrowingRoller(),
        idGenerator: SequentialIdGenerator(),
      );
      final simple = GenerationProcess(
        recordType: 'root',
        steps: const [
          RollStep(table: 'origin', field: 'origin'),
        ],
      );
      final records = runner.run(simple, overrides: {'origin': 'pinned'});
      expect(records.single.fields['origin'], 'pinned');
    });

    test('modifierFrom uses accumulator', () {
      final tables = TableRegistry.fromJson({
        'tables': {
          'first': {
            'type': 'random',
            'dice': {'count': 1, 'sides': 1, 'bonus': 0},
            'entries': [
              {
                'min': 1,
                'max': 1,
                'value': 'a',
                'modifiers': {'boost': 2},
              },
            ],
          },
          'second': {
            'type': 'random',
            'dice': {'count': 1, 'sides': 4, 'bonus': 0},
            'entries': [
              {'min': 1, 'max': 1, 'value': 'low'},
              {'min': 2, 'max': 2, 'value': 'mid'},
              {'min': 3, 'max': 5, 'value': 'high'},
            ],
          },
        },
      });
      final runner = ProcessRunner(
        registry: tables,
        // first always 1; second rolls 1 + boost 2 => 3 => high
        roller: SeededRoller([1, 1]),
        idGenerator: SequentialIdGenerator(),
      );
      final records = runner.run(
        GenerationProcess(
          recordType: 'root',
          steps: const [
            RollStep(table: 'first', field: 'a'),
            RollStep(table: 'second', field: 'b', modifierFrom: 'boost'),
          ],
        ),
      );
      expect(records.single.fields['b'], 'high');
    });
  });

  group('RecordFactoryRegistry', () {
    test('dispatches by type', () {
      final factory = RecordFactoryRegistry();
      factory.register('fake', (r) => 'built:${r.fields['n']}');
      final out = factory.build(
        GeneratedRecord(id: '1', type: 'fake', fields: {'n': 7}),
      );
      expect(out, 'built:7');
    });
  });
}
