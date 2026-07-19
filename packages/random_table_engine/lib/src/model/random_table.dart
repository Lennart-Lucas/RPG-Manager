import '../core/dice_formula.dart';
import '../core/roller.dart';
import 'roll_result.dart';
import 'table_entry.dart';
import 'table_registry.dart';

enum DuplicatePolicy {
  keepDuplicates,
  rerollDuplicates,
  ignoreDuplicates;

  static DuplicatePolicy fromJson(Object? raw) {
    final value = raw as String? ?? 'keepDuplicates';
    return DuplicatePolicy.values.firstWhere(
      (e) => e.name == value,
      orElse: () => throw FormatException('Unknown duplicatePolicy: $value'),
    );
  }
}

/// A rollable random table with optional sub-tables and duplicate handling.
class RandomTable {
  RandomTable({
    required this.id,
    required this.dice,
    required this.entries,
    this.duplicatePolicy = DuplicatePolicy.keepDuplicates,
    this.maxRerollAttempts = 20,
  }) {
    if (entries.isEmpty) {
      throw FormatException('RandomTable "$id" must have at least one entry');
    }
    _low = entries.map((e) => e.min).reduce((a, b) => a < b ? a : b);
    _high = entries.map((e) => e.max).reduce((a, b) => a > b ? a : b);
  }

  final String id;
  final DiceFormula dice;
  final List<TableEntry> entries;
  final DuplicatePolicy duplicatePolicy;
  final int maxRerollAttempts;

  late final int _low;
  late final int _high;

  int get lowest => _low;
  int get highest => _high;

  factory RandomTable.fromJson(String id, Map<String, dynamic> json) {
    final diceRaw = json['dice'];
    if (diceRaw is! Map) {
      throw FormatException('RandomTable "$id" requires dice object');
    }
    final diceMap = diceRaw is Map<String, dynamic>
        ? diceRaw
        : Map<String, dynamic>.from(diceRaw);
    final entriesRaw = json['entries'];
    if (entriesRaw is! List) {
      throw FormatException('RandomTable "$id" requires entries list');
    }
    final entries = <TableEntry>[];
    for (final item in entriesRaw) {
      if (item is! Map) {
        throw FormatException('RandomTable "$id" has invalid entry');
      }
      final entryMap =
          item is Map<String, dynamic> ? item : Map<String, dynamic>.from(item);
      entries.add(TableEntry.fromJson(entryMap));
    }
    return RandomTable(
      id: id,
      dice: DiceFormula.fromJson(diceMap),
      entries: entries,
      duplicatePolicy: DuplicatePolicy.fromJson(json['duplicatePolicy']),
      maxRerollAttempts: () {
        final raw = json['maxRerollAttempts'];
        if (raw == null) return 20;
        if (raw is int) return raw;
        if (raw is num) return raw.toInt();
        return 20;
      }(),
    );
  }

  int _clamp(int roll) {
    if (roll < _low) return _low;
    if (roll > _high) return _high;
    return roll;
  }

  TableEntry _entryFor(int clamped) {
    for (final entry in entries) {
      if (entry.matches(clamped)) return entry;
    }
    throw StateError(
      'RandomTable "$id": no entry matches clamped roll $clamped '
      '(bounds $_low..$_high)',
    );
  }

  RollResult roll(
    Roller roller,
    TableRegistry registry, {
    int modifier = 0,
    bool Function(String value)? rerollIf,
  }) {
    var attempts = 0;
    while (true) {
      attempts++;
      final diceResult = dice.roll(roller);
      final total = diceResult + modifier;
      final clamped = _clamp(total);
      final entry = _entryFor(clamped);
      if (rerollIf != null &&
          rerollIf(entry.value) &&
          attempts < maxRerollAttempts) {
        continue;
      }

      RollResult? detail;
      if (entry.subTable != null && entry.subTable!.isNotEmpty) {
        final sub = registry.get(entry.subTable!);
        detail = sub.roll(roller, registry, modifier: modifier);
      }

      return RollResult(
        value: entry.value,
        detail: detail,
        modifiers: entry.modifiers,
        tags: entry.tags,
        roll: diceResult,
        modifier: modifier,
        total: total,
        clamped: clamped,
      );
    }
  }

  List<RollResult> rollMany(
    int count,
    Roller roller,
    TableRegistry registry, {
    int modifier = 0,
    bool Function(String value)? rerollIf,
  }) {
    if (count < 0) {
      throw ArgumentError.value(count, 'count', 'must be >= 0');
    }
    final results = <RollResult>[];
    final seen = <String>{};

    for (var i = 0; i < count; i++) {
      switch (duplicatePolicy) {
        case DuplicatePolicy.keepDuplicates:
          results.add(
            roll(roller, registry, modifier: modifier, rerollIf: rerollIf),
          );
        case DuplicatePolicy.ignoreDuplicates:
          final result = roll(
            roller,
            registry,
            modifier: modifier,
            rerollIf: rerollIf,
          );
          if (seen.add(result.value)) {
            results.add(result);
          }
        case DuplicatePolicy.rerollDuplicates:
          var attempts = 0;
          late RollResult result;
          while (true) {
            attempts++;
            result = roll(
              roller,
              registry,
              modifier: modifier,
              rerollIf: rerollIf,
            );
            if (!seen.contains(result.value) ||
                attempts >= maxRerollAttempts) {
              break;
            }
          }
          seen.add(result.value);
          results.add(result);
      }
    }
    return results;
  }
}
