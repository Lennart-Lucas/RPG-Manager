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
    for (final item in stepsRaw) {
      if (item is! Map<String, dynamic>) {
        throw FormatException('Process steps must be objects');
      }
      steps.add(ProcessStep.fromJson(item));
    }
    return GenerationProcess(recordType: recordType, steps: steps);
  }
}
