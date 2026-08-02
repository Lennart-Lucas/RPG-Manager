import '../model/table_registry.dart';
import 'process_step.dart';

/// Declarative generation recipe that produces linked [GeneratedRecord]s.
class GenerationProcess {
  const GenerationProcess({
    required this.recordType,
    required this.steps,
  });

  final String recordType;
  final List<ProcessStep> steps;

  factory GenerationProcess.fromJson(Map<String, dynamic> json) {
    final recordType = json['recordType'];
    if (recordType is! String || recordType.isEmpty) {
      throw FormatException('GenerationProcess requires recordType');
    }
    final stepsRaw = json['steps'];
    if (stepsRaw is! List) {
      throw FormatException('GenerationProcess requires steps list');
    }
    final steps = <ProcessStep>[];
    for (var i = 0; i < stepsRaw.length; i++) {
      final item = stepsRaw[i];
      if (item is! Map) {
        throw FormatException('Process steps[$i] must be an object');
      }
      try {
        steps.add(
          ProcessStep.fromJson(
            item is Map<String, dynamic>
                ? item
                : Map<String, dynamic>.from(item),
          ),
        );
      } catch (e) {
        throw FormatException('Process steps[$i]: $e');
      }
    }
    return GenerationProcess(recordType: recordType, steps: steps);
  }

  /// Validates step table refs against [registry].
  ///
  /// Returns human-readable errors with paths like `steps[2].table`.
  /// Empty list means OK.
  List<String> validate(TableRegistry registry) {
    final errors = <String>[];
    void walk(List<ProcessStep> list, String path) {
      for (var i = 0; i < list.length; i++) {
        final step = list[i];
        final stepPath = '$path[$i]';
        switch (step) {
          case RollStep():
            if (!registry.hasRandom(step.table)) {
              errors.add(
                '$stepPath.table: unknown random table "${step.table}"',
              );
            }
          case LookupStep():
            if (!registry.hasLookup(step.table)) {
              errors.add(
                '$stepPath.table: unknown lookup table "${step.table}"',
              );
            }
          case RollManyStep():
            if (!registry.hasRandom(step.table)) {
              errors.add(
                '$stepPath.table: unknown random table "${step.table}"',
              );
            }
          case GateStep():
            if (!registry.hasRandom(step.table)) {
              errors.add(
                '$stepPath.table: unknown random table "${step.table}"',
              );
            }
            walk(step.thenSteps, '$stepPath.then');
          case AddDefaultRecordStep():
            break;
        }
      }
    }

    walk(steps, 'steps');
    return errors;
  }
}
