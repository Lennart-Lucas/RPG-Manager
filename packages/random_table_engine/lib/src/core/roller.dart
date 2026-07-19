import 'dart:math';

/// Produces die rolls for table resolution and dice formulas.
abstract class Roller {
  /// Rolls a single die with [sides] faces (1..sides inclusive).
  int roll(int sides);

  /// Rolls [count] dice with [sides] faces and returns the sum.
  int rollSum(int count, int sides) {
    var total = 0;
    for (var i = 0; i < count; i++) {
      total += roll(sides);
    }
    return total;
  }
}

/// Production roller backed by [Random].
class RandomRoller extends Roller {
  RandomRoller([Random? random]) : _random = random ?? Random();

  final Random _random;

  @override
  int roll(int sides) {
    if (sides < 1) {
      throw ArgumentError.value(sides, 'sides', 'must be >= 1');
    }
    return _random.nextInt(sides) + 1;
  }
}

/// Deterministic roller that returns values from a fixed sequence (cycles).
class SeededRoller extends Roller {
  SeededRoller(List<int> sequence)
      : _sequence = List<int>.unmodifiable(sequence) {
    if (_sequence.isEmpty) {
      throw ArgumentError('SeededRoller sequence must not be empty');
    }
  }

  final List<int> _sequence;
  var _index = 0;

  @override
  int roll(int sides) {
    if (sides < 1) {
      throw ArgumentError.value(sides, 'sides', 'must be >= 1');
    }
    final value = _sequence[_index % _sequence.length];
    _index++;
    if (value < 1 || value > sides) {
      throw StateError(
        'Seeded roll $value is outside 1..$sides',
      );
    }
    return value;
  }
}
