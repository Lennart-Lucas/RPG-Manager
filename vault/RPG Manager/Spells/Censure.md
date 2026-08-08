---
rpg_manager_id: 77
rpg_manager_kind: "spells"
name: "Censure"
id: "censure"
level: 2
school: "evocation"
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
  type: "instantaneous"
  concentration: false
classIds:
  - 2
  - 5
  - 6
  - 7
  - 10
tagIds: []
savingThrow: "none"
attackType: "none"
sourceFileId: 1
sourcePage: 3
---

## Description

Bright light pulses in a 20-foot-radius Sphere from a point you choose within range. Each enemy creature in the Sphere must succeed on a Constitution saving throw or be suppressed until the end of your next turn. While suppressed by this spell, a creature takes 2d10 [[RPG Manager/Damage Types/Radiant]] damage each time it casts a spell, and it cannot use component pouches or spellcasting foci for Material component requirements.

## At higher levels

The radius increases by 10 feet for each spell slot level above 2.
