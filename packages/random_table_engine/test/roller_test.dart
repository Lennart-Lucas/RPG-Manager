import 'package:random_table_engine/generation_engine.dart';
import 'package:test/test.dart';

void main() {
  group('SeededRoller', () {
    test('returns seeded value within range', () {
      expect(SeededRoller([5]).roll(20), 5);
    });

    test('cycles sequence', () {
      final roller = SeededRoller([1, 2]);
      expect(roller.roll(6), 1);
      expect(roller.roll(6), 2);
      expect(roller.roll(6), 1);
    });
  });

  group('DiceFormula', () {
    test('rolls count*dice + bonus', () {
      expect(DiceFormula(count: 1, sides: 8, bonus: 2).roll(SeededRoller([3])), 5);
    });

    test('fromJson', () {
      final f = DiceFormula.fromJson({'count': 2, 'sides': 6, 'bonus': 1});
      expect(f.count, 2);
      expect(f.sides, 6);
      expect(f.bonus, 1);
    });
  });

  group('RandomRoller', () {
    test('stays in 1..sides', () {
      final roller = RandomRoller();
      for (var i = 0; i < 100; i++) {
        final v = roller.roll(6);
        expect(v, inInclusiveRange(1, 6));
      }
    });
  });
}
