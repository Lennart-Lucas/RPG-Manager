import 'package:rpg_manager/features/world/creatures/data/creature_model.dart';

class LabeledAmount {
  const LabeledAmount({required this.label, required this.amount});

  final String label;
  final num amount;

  factory LabeledAmount.fromJson(Map<String, dynamic> json) {
    final rawAmount = json['amount'];
    num amount = 0;
    if (rawAmount is num) {
      amount = rawAmount;
    } else if (rawAmount is String) {
      amount = num.tryParse(rawAmount) ?? 0;
    }
    return LabeledAmount(
      label: json['label'] as String? ?? '',
      amount: amount,
    );
  }

  Map<String, dynamic> toJson() => {'label': label, 'amount': amount};

  LabeledAmount copyWith({String? label, num? amount}) {
    return LabeledAmount(
      label: label ?? this.label,
      amount: amount ?? this.amount,
    );
  }
}

List<LabeledAmount> labeledAmountsFromJson(dynamic raw) {
  if (raw is! List) return const [];
  final out = <LabeledAmount>[];
  for (final e in raw) {
    if (e is Map<String, dynamic>) {
      out.add(LabeledAmount.fromJson(e));
    } else if (e is Map) {
      out.add(LabeledAmount.fromJson(Map<String, dynamic>.from(e)));
    }
  }
  return out;
}

List<Map<String, dynamic>> labeledAmountsToJson(List<LabeledAmount> items) {
  return [for (final item in items) item.toJson()];
}

String labeledAmountsDisplay(List<LabeledAmount> items) {
  return items
      .where((e) => e.label.trim().isNotEmpty)
      .map((e) {
        final amount = e.amount;
        final amountText =
            amount % 1 == 0 ? amount.toInt().toString() : '$amount';
        return '${e.label} $amountText ft.';
      })
      .join(', ');
}

int? walkSpeedFromMovement(List<LabeledAmount> movement) {
  for (final entry in movement) {
    final label = entry.label.trim().toLowerCase();
    if (label == 'normal' || label == 'walk') {
      return entry.amount.round();
    }
  }
  return null;
}

CreatureSpeeds syncSpeedsFromMovement({
  required CreatureSpeeds speeds,
  required List<LabeledAmount> movement,
}) {
  var next = speeds;
  for (final entry in movement) {
    final label = entry.label.trim().toLowerCase();
    final value = entry.amount.round();
    switch (label) {
      case 'normal':
      case 'walk':
        next = next.copyWith(walk: value);
      case 'fly':
        next = next.copyWith(fly: value);
      case 'swim':
        next = next.copyWith(swim: value);
      case 'climb':
        next = next.copyWith(climb: value);
      case 'burrow':
        next = next.copyWith(burrow: value);
    }
  }
  return next;
}

List<LabeledAmount> movementFromSpeeds(CreatureSpeeds speeds) {
  return [
    LabeledAmount(label: 'Normal', amount: speeds.walk),
    if (speeds.fly != null) LabeledAmount(label: 'Fly', amount: speeds.fly!),
    if (speeds.swim != null) LabeledAmount(label: 'Swim', amount: speeds.swim!),
    if (speeds.climb != null)
      LabeledAmount(label: 'Climb', amount: speeds.climb!),
    if (speeds.burrow != null)
      LabeledAmount(label: 'Burrow', amount: speeds.burrow!),
  ];
}

List<LabeledAmount> mergeLabeledAmounts(
  List<LabeledAmount> existing,
  List<LabeledAmount> incoming,
) {
  String key(LabeledAmount value) =>
      '${value.label.trim().toLowerCase()}|${value.amount}';
  final seen = {for (final value in existing) key(value)};
  final merged = [...existing];
  for (final value in incoming) {
    if (!seen.add(key(value))) continue;
    merged.add(value);
  }
  return merged;
}
