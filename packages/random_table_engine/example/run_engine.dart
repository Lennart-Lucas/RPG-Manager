import 'dart:convert';
import 'dart:io';

import 'package:random_table_engine/generation_engine.dart';

/// Throwaway end-to-end demo: load fixtures, run process, print records.
void main() {
  final packageRoot = Directory.current.path.endsWith('example')
      ? '..'
      : '.';
  final tables = TableRegistry.fromJson(
    jsonDecode(
      File('$packageRoot/test/fixtures/process_tables.json').readAsStringSync(),
    ) as Map<String, dynamic>,
  );
  final process = GenerationProcess.fromJson(
    jsonDecode(
      File('$packageRoot/test/fixtures/process.json').readAsStringSync(),
    ) as Map<String, dynamic>,
  );

  final records = ProcessRunner(
    registry: tables,
    roller: SeededRoller([1, 3, 1, 1, 2, 1, 1]),
    idGenerator: SequentialIdGenerator(),
  ).run(process);

  for (final record in records) {
    stdout.writeln(record);
  }
}
