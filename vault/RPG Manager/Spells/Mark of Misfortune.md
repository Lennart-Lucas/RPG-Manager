---
rpg_manager_id: 48
rpg_manager_kind: "spells"
name: "Mark of Misfortune"
id: "mark-of-misfortune"
level: 3
school: "divination"
castingTime:
  amount: 1
  unit: "action"
range:
  type: "ranged"
  distanceFeet: 60
components:
  verbal: true
  somatic: true
  material: false
  materialConsumed: false
duration:
  type: "oneHour"
  concentration: false
classIds:
  - 10
tagIds:
  - 62
savingThrow: "none"
attackType: "none"
sourceFileId: 4
sourcePage: 2
---

## Description

Choose a creature within range. For the duration, it takes 5 [[RPG Manager/Damage Types/Psychic]] damage every time it fails an attack, an ability check, or a saving throw. Once the target has taken a total of 30 damage from this spell, the spell ends.
In addition, when a feature or a spell requires you to target a creature affected by the Hex spell (such as the Maddening Hex Eldritch Invocation), it also works against a creature affected by this spell.

## At higher levels

When you cast this spell using a 4th-level spell slot or higher, the [[RPG Manager/Damage Types/Psychic]] damage increases by 1 and the maximum damage before the spell ends increases by 5 for each spell level above 3rd.
