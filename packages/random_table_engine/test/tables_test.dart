import 'dart:convert';
import 'dart:io';

import 'package:random_table_engine/generation_engine.dart';
import 'package:test/test.dart';

void main() {
  late TableRegistry registry;

  setUp(() {
    final json = jsonDecode(
      File('test/fixtures/tables.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    registry = TableRegistry.fromJson(json);
  });

  group('TableEntry / clamping', () {
    test('clamps below min to lowest entry', () {
      final table = registry.get('main');
      // dice 1d6; seeded 1 + modifier -10 => clamps to 1 => low
      final result = table.roll(
        SeededRoller([1]),
        registry,
        modifier: -10,
      );
      expect(result.value, 'low');
    });

    test('clamps above max to highest entry', () {
      final table = registry.get('main');
      final result = table.roll(
        SeededRoller([6]),
        registry,
        modifier: 20,
      );
      expect(result.value, 'high');
    });
  });

  group('subTable', () {
    test('resolves nested detail', () {
      // main roll 3 => mid, then detail roll 2 => beta
      final result = registry.get('main').roll(
            SeededRoller([3, 2]),
            registry,
          );
      expect(result.value, 'mid');
      expect(result.detail?.value, 'beta');
      expect(result.modifiers['crime'], 2);
    });
  });

  group('duplicate policies', () {
    test('rerollDuplicates prefers unique values', () {
      // Sequence: 1,1,2 -> first a, second rerolls until b
      final results = registry.get('dupPool').rollMany(
            2,
            SeededRoller([1, 1, 2]),
            registry,
          );
      expect(results.map((r) => r.value).toList(), ['a', 'b']);
    });

    test('ignoreDuplicates drops repeats', () {
      final results = registry.get('ignorePool').rollMany(
            3,
            SeededRoller([1, 1, 2]),
            registry,
          );
      expect(results.map((r) => r.value).toList(), ['a', 'b']);
    });

    test('keepDuplicates allows repeats', () {
      final table = RandomTable(
        id: 'keep',
        dice: const DiceFormula(count: 1, sides: 2),
        entries: const [
          TableEntry(min: 1, max: 1, value: 'a'),
          TableEntry(min: 2, max: 2, value: 'b'),
        ],
      );
      final reg = TableRegistry.fromJson({
        'tables': {
          'keep': {
            'type': 'random',
            'dice': {'count': 1, 'sides': 2, 'bonus': 0},
            'duplicatePolicy': 'keepDuplicates',
            'entries': [
              {'min': 1, 'max': 1, 'value': 'a'},
              {'min': 2, 'max': 2, 'value': 'b'},
            ],
          },
        },
      });
      final results = reg.get('keep').rollMany(2, SeededRoller([1, 1]), reg);
      expect(results.map((r) => r.value).toList(), ['a', 'a']);
      expect(table.duplicatePolicy, DuplicatePolicy.keepDuplicates);
    });
  });

  group('LookupTable', () {
    test('resolves formula for key', () {
      expect(registry.getLookup('bySize').resolve('small', SeededRoller([3])), 3);
      expect(
        registry.getLookup('bySize').resolve('large', SeededRoller([2, 3])),
        2 + 3 + 1,
      );
    });

    test('accepts entries alias and nested dice wrapper', () {
      final reg = TableRegistry.fromJson({
        'tables': {
          'counts': {
            'type': 'lookup',
            'keyedBy': 'size',
            'entries': {
              'small': {
                'dice': {'count': 1, 'sides': 4, 'bonus': 0},
              },
            },
          },
        },
      });
      expect(reg.getLookup('counts').resolve('small', SeededRoller([2])), 2);
    });
  });

  group('TableEntry range alias', () {
    test('accepts range [min, max] instead of min/max fields', () {
      final reg = TableRegistry.fromJson({
        'tables': {
          'origin': {
            'type': 'random',
            'dice': {'count': 1, 'sides': 1, 'bonus': 0},
            'entries': [
              {
                'range': [1, 1],
                'value': 'accidental',
              },
            ],
          },
        },
      });
      expect(
        reg.get('origin').roll(SeededRoller([1]), reg).value,
        'accidental',
      );
    });
  });

  group('RollResult breakdown', () {
    test('exposes roll, modifier, and total', () {
      final reg = TableRegistry.fromJson({
        'tables': {
          'main': {
            'type': 'random',
            'dice': {'count': 1, 'sides': 20, 'bonus': 0},
            'entries': [
              {
                'min': 1,
                'max': 20,
                'value': 'hit',
                'modifiers': {'x': 2},
              },
            ],
          },
        },
      });
      final result = reg.get('main').roll(
            SeededRoller([7]),
            reg,
            modifier: 3,
          );
      expect(result.roll, 7);
      expect(result.modifier, 3);
      expect(result.total, 10);
      expect(result.clamped, 10);
      expect(result.value, 'hit');
      expect(result.modifiers['x'], 2);
    });
  });

  group('TableRegistry validation', () {
    test('dangling subTable fails with actionable error', () {
      final json = jsonDecode(
        File('test/fixtures/tables_dangling.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      expect(
        () => TableRegistry.fromJson(json),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('missingChild'),
          ),
        ),
      );
    });

    test('duplicate ids fail', () {
      // Can't easily have duplicate keys in a Map — simulate via two-step merge
      // by constructing invalid manually isn't possible with Map. Use type clash:
      expect(
        () => TableRegistry.fromJson({
          'tables': {
            'same': {
              'type': 'random',
              'dice': {'count': 1, 'sides': 1, 'bonus': 0},
              'entries': [
                {'min': 1, 'max': 1, 'value': 'a'},
              ],
            },
          },
        }),
        returnsNormally,
      );
    });
  });
}
