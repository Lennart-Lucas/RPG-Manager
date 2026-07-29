# Random Generator Config Guide

Hand this document to an AI (or human author) that needs to produce valid generator JSON for RPG Manager.

Generators are catalog records (`CatalogKind.generators`) with a payload shaped like:

```json
{
  "name": "Settlement",
  "tablesDocument": { "tables": { "...": { } } },
  "processDocument": { "recordType": "...", "steps": [ ] }
}
```

| Piece | Role |
|-------|------|
| Runtime engine | Dart package `packages/random_table_engine` |
| App wrapper | `frontend/lib/features/settings/generators/data/generator_model.dart` |
| Short schema summary | [README.md](./README.md) |

Running a generator produces **preview** `GeneratedRecord`s only. Nothing is persisted to the world catalog until a later product step does so.

---

## 1. Mental model

1. **Tables** define *what can be rolled* (bands, dice, modifiers, nested detail).
2. **Process** defines *the recipe*: which tables to roll, in what order, how results become fields or child records.
3. **Modifiers** are named integers accumulated from rolled entries. Later `roll` steps can add a named modifier total to the dice (`modifierFrom`).
4. Output is a list of linked records: one **root** (`process.recordType`) plus optional **children** (`emitAs` / `addDefaultRecord`).

Author tables first (or in parallel), then a process that only references table ids that exist.

---

## 2. Top-level catalog payload

```json
{
  "name": "Human-readable generator name",
  "tablesDocument": {
    "tables": {
      "<tableId>": { }
    }
  },
  "processDocument": {
    "recordType": "settlement",
    "steps": [ ]
  }
}
```

### Paste / import flexibility (app UI)

When pasting into the generator form, `tablesDocument` also accepts:

| Paste shape | How it is normalized |
|-------------|----------------------|
| `{ "tables": { … } }` | Canonical — used as-is |
| Full catalog payload with `tablesDocument` | Nested document is extracted; if `processDocument` / `name` are present they may be applied too |
| Bare map of table ids → table objects | Wrapped as `{ "tables": { … } }` |

Prefer the **canonical** nested shapes below for AI-authored configs.

---

## 3. Dice formula

Used by random tables and lookup table values.

```json
{ "count": 1, "sides": 20, "bonus": 0 }
```

| Field | Type | Required | Rules |
|-------|------|----------|-------|
| `count` | int | yes | ≥ 1 |
| `sides` | int | yes | ≥ 1 |
| `bonus` | int | no | Default `0` |

Roll result = sum of `count` dice of `sides` faces, plus `bonus`.

---

## 4. Tables document

```json
{
  "tables": {
    "<id>": { "type": "random" | "lookup", ... }
  }
}
```

- Table ids are strings (keys of `tables`). Use stable, lowercase ids (`origin`, `shopCount`).
- `type` defaults to `"random"` if omitted.
- Ids must be unique across random and lookup tables.
- Validation fails if a random entry’s `subTable` points at a missing **random** table.

### 4.1 Random table (`"type": "random"`)

```json
{
  "type": "random",
  "dice": { "count": 1, "sides": 6, "bonus": 0 },
  "duplicatePolicy": "keepDuplicates",
  "maxRerollAttempts": 20,
  "entries": [
    {
      "min": 1,
      "max": 2,
      "value": "low",
      "subTable": "detail",
      "modifiers": { "crime": 1 },
      "tags": { "rare": true }
    }
  ]
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `dice` | dice object | yes | Formula rolled each attempt |
| `entries` | array | yes | At least one band |
| `duplicatePolicy` | string | no | See below; default `keepDuplicates` |
| `maxRerollAttempts` | int | no | Cap for duplicate / value rerolls; default `20` |

#### Entries

Each entry is a contiguous integer band. Prefer either `min`/`max` **or** `range`:

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `min`, `max` | int | one style | Inclusive band; `min` ≤ `max` |
| `range` | `[min, max]` | alt style | Same as min/max |
| `value` | **string** | yes | Result text (numbers must be strings, e.g. `"2"`) |
| `subTable` | string | no | Id of another **random** table rolled for detail |
| `modifiers` | `{ name: int }` | no | Added to the process modifier accumulator |
| `tags` | object | no | Free-form metadata on the roll result |

**Roll selection**

1. Roll dice, add optional process modifier → `total`.
2. Clamp `total` to the table’s overall lowest/highest entry bounds (not list order).
3. Pick the first entry whose `[min, max]` contains the clamped value.
4. If `subTable` is set, roll that table (same modifier) and attach as `detail`.

Bands should cover the intended range without gaps you care about. Gaps inside the clamp span will throw at runtime if a clamped roll hits them.

#### Duplicate policies (used by `rollMany`)

| Value | Behavior |
|-------|----------|
| `keepDuplicates` | Always keep the rolled value (default) |
| `rerollDuplicates` | Reroll until value is new among this batch, or attempts exhausted |
| `ignoreDuplicates` | Skip adding a result if its value was already seen (batch may be shorter than `count`) |

### 4.2 Lookup table (`"type": "lookup"`)

Maps a string key to a dice formula, then rolls that formula. Used by process op `lookup`.

```json
{
  "type": "lookup",
  "keyedBy": "origin",
  "values": {
    "north": { "count": 1, "sides": 4, "bonus": 0 },
    "south": { "count": 1, "sides": 6, "bonus": 0 }
  }
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `keyedBy` | string | yes | Documented name of the field that supplies the key (informational; process uses `keyField`) |
| `values` | map | yes | Key → dice formula. Alias: `entries` (same map shape) |

Each value must be a dice formula object. Nested `{ "dice": { … } }` is also accepted (unwraps to the inner formula).

Missing keys throw at runtime when resolved.

---

## 5. Process document

```json
{
  "recordType": "settlement",
  "steps": [
    { "op": "roll", "table": "origin", "field": "origin" }
  ]
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `recordType` | string | yes | Type of the root `GeneratedRecord` |
| `steps` | array | yes | Ordered ops (may be empty) |

Unknown `op` values fail validation.

### Shared step concepts

| Concept | Meaning |
|---------|---------|
| `table` | Id of a random or lookup table (must match op) |
| `field` | Field name written on the **current** record |
| `emitAs` | If set, create a **child** record of this type instead of merging into current |
| `parentField` | Optional label on the child linking it to the parent (e.g. `"shops"`) |
| `staticFields` | Extra constant fields merged onto the written record |
| `fieldMap` | Rename: `{ "fromKey": "toKey" }` copies/renames within the field bag |
| `modifierFrom` | (`roll` only) Name of a modifier channel to add to the dice total |

**Child vs field merge**

- Without `emitAs`: fields merge into the current record (root, or the child inside a gate).
- With `emitAs`: a new record is appended; its `parentId` is the current scope; nested gate `then` steps run with that child as current.

**Automatic fields from rolls**

- Primary result → `field` (or `value` on rollMany children).
- Sub-table detail → `{field}Detail` (or `detail` on rollMany children).
- Roll breakdown meta → reserved `_rolls` map on the record.
- After the full run, root also gets `_modifiers` (snapshot of all accumulated named modifiers).

Do not author `_rolls` / `_modifiers` in config; the engine writes them.

---

## 6. Process ops

### 6.1 `roll`

Roll a **random** table once; write onto current or emit a child.

```json
{
  "op": "roll",
  "table": "origin",
  "field": "origin",
  "modifierFrom": "wealth",
  "emitAs": null,
  "parentField": null,
  "fieldMap": { "origin": "region" },
  "staticFields": { "source": "table" }
}
```

| Field | Required | Notes |
|-------|----------|-------|
| `table` | yes | Random table id |
| `field` | yes | Destination field for `value` |
| `modifierFrom` | no | Named modifier total applied to dice |
| `emitAs` | no | Child record type |
| `parentField` | no | Child link label |
| `fieldMap` | no | String→string renames |
| `staticFields` | no | Constants |

If the runner is given **overrides** for `field`, that pinned value is used and the table is not rolled (app may use this later; ignore for static configs).

### 6.2 `lookup`

Resolve a **lookup** table using an existing field on the current record; write an **integer** roll result.

```json
{
  "op": "lookup",
  "table": "wealthDie",
  "keyField": "origin",
  "field": "wealthRoll"
}
```

| Field | Required | Notes |
|-------|----------|-------|
| `table` | yes | Lookup table id |
| `keyField` | yes | Must already exist on current record |
| `field` | yes | Destination (int) |

Order matters: roll/set `keyField` before this step.

### 6.3 `rollMany`

Roll a **random** table `N` times, where `N` comes from a field on the current record.

```json
{
  "op": "rollMany",
  "table": "shops",
  "countField": "shopCount",
  "emitAs": "shop",
  "parentField": "shops",
  "fieldMap": { "value": "name" },
  "staticFields": { "kind": "shop" },
  "rerollIfTag": "skip"
}
```

| Field | Required | Notes |
|-------|----------|-------|
| `table` | yes | Random table id |
| `countField` | yes | Field holding count: int, num, or numeric string |
| `field` | no | If **not** emitting: list field name (default = table id) |
| `emitAs` | no | Emit one child per result |
| `parentField` | no | Child link label |
| `fieldMap` | no | Typical: `{ "value": "name" }` |
| `staticFields` | no | Constants on each child / ignored for list mode extras |
| `rerollIfTag` | no | Despite the name: **reroll while the rolled `value` equals this string** (not entry `tags`) |

**With `emitAs`:** each result becomes a child with fields `value`, optional `detail`, plus maps/statics.

**Without `emitAs`:** current record gets `field` → `List<String>` of values.

Duplicate handling uses the table’s `duplicatePolicy`.

### 6.4 `gate`

Roll a random table; only run nested `then` steps if the value equals `proceedValue`.

```json
{
  "op": "gate",
  "table": "hasTemple",
  "proceedValue": "yes",
  "field": "hasTemple",
  "emitAs": "temple",
  "parentField": "temple",
  "staticFields": {},
  "then": [
    { "op": "roll", "table": "templeSize", "field": "size" }
  ]
}
```

| Field | Required | Notes |
|-------|----------|-------|
| `table` | yes | Random table id |
| `proceedValue` | yes | Exact string match against rolled `value` |
| `then` | yes | Nested step list (may be empty) |
| `field` | no | Store gate roll on current or child |
| `emitAs` | no | If set and gate passes: create child, run `then` with child as current |
| `parentField` | no | Child link label |
| `staticFields` | no | Applied to child when emitting |

If the gate fails: optional `field` / roll meta may still be written on current; `then` is skipped.

### 6.5 `addDefaultRecord`

Always emit a child with only static fields (no roll).

```json
{
  "op": "addDefaultRecord",
  "emitAs": "note",
  "parentField": "notes",
  "staticFields": { "text": "generated" }
}
```

| Field | Required | Notes |
|-------|----------|-------|
| `emitAs` | yes | Child type |
| `parentField` | no | Link label |
| `staticFields` | no | Field bag (default `{}`) |

---

## 7. Output shape (`GeneratedRecord`)

Each run returns a list of records:

```text
{
  id: string,              // UUID
  type: string,            // recordType / emitAs
  parentId: string?,       // null for root
  parentField: string?,    // grouping hint
  fields: {
    ...author fields...,
    "_rolls": { ... },     // roll breakdowns
    "_modifiers": { ... }  // root only, end of run
  }
}
```

Typical tree:

```text
settlement (root)
  ├─ shop  parentField=shops
  ├─ shop  parentField=shops
  ├─ temple parentField=temple
  └─ note  parentField=notes
```

---

## 8. Complete worked example

Same idea as the package test fixtures (`test/fixtures/process_tables.json` + `process.json`).

### Full catalog payload

```json
{
  "name": "Settlement demo",
  "tablesDocument": {
    "tables": {
      "origin": {
        "type": "random",
        "dice": { "count": 1, "sides": 2, "bonus": 0 },
        "entries": [
          { "min": 1, "max": 1, "value": "north", "modifiers": { "wealth": 1 } },
          { "min": 2, "max": 2, "value": "south", "modifiers": { "wealth": 2 } }
        ]
      },
      "shopCount": {
        "type": "random",
        "dice": { "count": 1, "sides": 1, "bonus": 0 },
        "entries": [
          { "min": 1, "max": 1, "value": "2" }
        ]
      },
      "shops": {
        "type": "random",
        "dice": { "count": 1, "sides": 2, "bonus": 0 },
        "duplicatePolicy": "rerollDuplicates",
        "entries": [
          { "min": 1, "max": 1, "value": "baker" },
          { "min": 2, "max": 2, "value": "smith" }
        ]
      },
      "hasTemple": {
        "type": "random",
        "dice": { "count": 1, "sides": 2, "bonus": 0 },
        "entries": [
          { "min": 1, "max": 1, "value": "yes" },
          { "min": 2, "max": 2, "value": "no" }
        ]
      },
      "templeSize": {
        "type": "random",
        "dice": { "count": 1, "sides": 1, "bonus": 0 },
        "entries": [
          { "min": 1, "max": 1, "value": "modest" }
        ]
      },
      "wealthDie": {
        "type": "lookup",
        "keyedBy": "origin",
        "values": {
          "north": { "count": 1, "sides": 4, "bonus": 0 },
          "south": { "count": 1, "sides": 6, "bonus": 0 }
        }
      }
    }
  },
  "processDocument": {
    "recordType": "settlement",
    "steps": [
      { "op": "roll", "table": "origin", "field": "origin" },
      {
        "op": "lookup",
        "table": "wealthDie",
        "keyField": "origin",
        "field": "wealthRoll"
      },
      { "op": "roll", "table": "shopCount", "field": "shopCount" },
      {
        "op": "rollMany",
        "table": "shops",
        "countField": "shopCount",
        "emitAs": "shop",
        "parentField": "shops",
        "fieldMap": { "value": "name" }
      },
      {
        "op": "gate",
        "table": "hasTemple",
        "proceedValue": "yes",
        "emitAs": "temple",
        "parentField": "temple",
        "then": [
          { "op": "roll", "table": "templeSize", "field": "size" }
        ]
      },
      {
        "op": "addDefaultRecord",
        "emitAs": "note",
        "parentField": "notes",
        "staticFields": { "text": "generated" }
      }
    ]
  }
}
```

---

## 9. Authoring checklist (for AIs)

1. Emit **valid JSON** only (no comments, no trailing commas).
2. Put all tables under `tablesDocument.tables` and the recipe under `processDocument`.
3. Every `table` / `subTable` id must exist; `lookup` ops need `"type": "lookup"` tables; other ops need random tables.
4. Entry `value` is always a **string** (including numeric counts like `"3"`).
5. Cover dice ranges with entries; remember rolls are **clamped** to overall min/max bands.
6. Order process steps so `keyField` / `countField` exist before `lookup` / `rollMany`.
7. Prefer `emitAs` + `parentField` for collections (shops, NPCs); keep scalars on the root.
8. Use `modifiers` + later `modifierFrom` for “this result biases later rolls.”
9. Keep table ids and field names stable, `camelCase` or `snake_case`, no spaces.
10. Do not invent ops beyond: `roll`, `lookup`, `rollMany`, `gate`, `addDefaultRecord`.
11. Remember `rerollIfTag` matches the rolled **value** string, not `tags` keys.
12. Validate mentally: can the process run with empty overrides and only the declared tables?

---

## 10. Common mistakes

| Mistake | Symptom / fix |
|---------|----------------|
| Numeric `value`: `2` instead of `"2"` | Validation: `TableEntry.value must be a String` |
| `lookup` before the key field is rolled | Runtime: missing `keyField` |
| `countField` not parseable as int | Runtime on `rollMany` |
| `subTable` pointing at a lookup table | Registry validation error |
| Gaps in entry bands inside clamp range | Runtime: no entry matches |
| Using `tags` expecting `rerollIfTag` to read them | It compares against `value` only |
| Forgetting `type: "lookup"` | Table parsed as random and fails (needs `dice`/`entries`) |
| Unknown `op` | Process parse error |

---

## 11. Minimal template

```json
{
  "name": "Untitled generator",
  "tablesDocument": {
    "tables": {
      "main": {
        "type": "random",
        "dice": { "count": 1, "sides": 2, "bonus": 0 },
        "entries": [
          { "min": 1, "max": 1, "value": "a" },
          { "min": 2, "max": 2, "value": "b" }
        ]
      }
    }
  },
  "processDocument": {
    "recordType": "result",
    "steps": [
      { "op": "roll", "table": "main", "field": "result" }
    ]
  }
}
```

---

## 12. Local verification

From `packages/random_table_engine`:

```sh
dart test
dart run example/run_engine.dart
```

In the app: Settings → Generators → paste JSON → save (form runs `validateConfig()` via `TableRegistry` + `GenerationProcess` parse) → Run preview.
