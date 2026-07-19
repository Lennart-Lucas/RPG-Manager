import 'roller.dart';

/// A dice expression: [count]d[sides] + [bonus].
class DiceFormula {
  const DiceFormula({
    required this.count,
    required this.sides,
    this.bonus = 0,
  });

  final int count;
  final int sides;
  final int bonus;

  factory DiceFormula.fromJson(Map<String, dynamic> json) {
    int? asInt(Object? value) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      return null;
    }

    final count = asInt(json['count']);
    final sides = asInt(json['sides']);
    final bonus = asInt(json['bonus'] ?? 0);
    if (count == null || count < 1) {
      throw FormatException('DiceFormula.count must be an int >= 1, got $count');
    }
    if (sides == null || sides < 1) {
      throw FormatException('DiceFormula.sides must be an int >= 1, got $sides');
    }
    if (bonus == null) {
      throw FormatException('DiceFormula.bonus must be an int, got ${json['bonus']}');
    }
    return DiceFormula(count: count, sides: sides, bonus: bonus);
  }

  Map<String, dynamic> toJson() => {
        'count': count,
        'sides': sides,
        'bonus': bonus,
      };

  int roll(Roller roller) => roller.rollSum(count, sides) + bonus;
}
