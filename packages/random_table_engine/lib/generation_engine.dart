/// Public API for the random table generation engine.
library;

export 'src/core/dice_formula.dart';
export 'src/core/id_generator.dart';
export 'src/core/modifier_accumulator.dart';
export 'src/core/roller.dart';
export 'src/model/generated_record.dart';
export 'src/model/lookup_table.dart';
export 'src/model/random_table.dart' show DuplicatePolicy, RandomTable;
export 'src/model/roll_result.dart';
export 'src/model/table_entry.dart';
export 'src/model/table_registry.dart';
export 'src/process/generation_process.dart';
export 'src/process/process_runner.dart';
export 'src/process/process_step.dart';
export 'src/record_factory.dart';
