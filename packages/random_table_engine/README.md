# Random table engine

JSON-driven random table generation for Dart. Pure Dart — no Flutter dependency.

## Usage

```dart
import 'package:random_table_engine/generation_engine.dart';

final registry = TableRegistry.fromJson(tablesJson);
final process = GenerationProcess.fromJson(processJson);
final runner = ProcessRunner(
  registry: registry,
  roller: RandomRoller(),
  idGenerator: UuidIdGenerator(),
);
final records = runner.run(process);
```

Register typed builders in the app layer (not in this package):

```dart
final factory = RecordFactoryRegistry();
factory.register('settlement', (r) => MySettlement.fromGenerated(r));
```

## Tables JSON schema

Top-level object:

```json
{ "tables": { "<id>": { ... } } }
```

### Random table (`"type": "random"`, default)

| Field | Type | Description |
|-------|------|-------------|
| `dice` | `{count, sides, bonus?}` | Dice formula |
| `entries` | array | Bands with `min`, `max`, `value`, optional `subTable`, `modifiers`, `tags` |
| `duplicatePolicy` | string | `keepDuplicates` (default), `rerollDuplicates`, `ignoreDuplicates` |
| `maxRerollAttempts` | int | Cap for reroll / `rerollIf` (default 20) |

Rolls are clamped to the lowest/highest entry bounds (not list order). `subTable` must reference another random table id.

### Lookup table (`"type": "lookup"`)

| Field | Type | Description |
|-------|------|-------------|
| `keyedBy` | string | Documented key field name |
| `values` | map | Key → dice formula object |

## Process JSON schema

```json
{
  "recordType": "rootType",
  "steps": [ { "op": "...", ... } ]
}
```

### Ops

- **`roll`**: `table`, `field`, optional `modifierFrom`, `emitAs`, `parentField`, `fieldMap`, `staticFields`
- **`lookup`**: `table`, `keyField`, `field`
- **`rollMany`**: `table`, `countField`, optional `field`, `emitAs`, `parentField`, `staticFields`, `fieldMap`, `rerollIfTag`
- **`gate`**: `table`, `proceedValue`, `then` (nested steps), optional `field`, `emitAs`, `parentField`, `staticFields`
- **`addDefaultRecord`**: `emitAs`, optional `parentField`, `staticFields`

`overrides` on `ProcessRunner.run` pins root field values and skips rolling for matching `roll` steps.

## Example

```sh
dart run example/run_engine.dart
```

## Tests

```sh
dart test
```
