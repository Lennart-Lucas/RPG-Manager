---
rpg_manager_id: 77
rpg_manager_kind: "spells"
name: "Censure"
id: "censure"
level: 2
range:
  type: "ranged"
  distanceFeet: 60
school: "evocation"
tagIds: []
classIds:
  - 2
  - 5
  - 6
  - 7
  - 10
duration:
  type: "instantaneous"
  concentration: false
attackType: "none"
components:
  verbal: true
  somatic: true
  material: false
  materialConsumed: false
sourcePage: 3
castingTime:
  unit: "action"
  amount: 1
savingThrow: "none"
sourceFileId: 1
---

Bright light pulses in a 20-foot-radius Sphere from a point you choose within range. Each enemy creature in the Sphere must succeed on a Constitution saving throw or be suppressed until the end of your next turn. While suppressed by this spell, a creature takes 2d10 [[RPG Manager/Damage Types/Radiant]] damage each time it casts a spell, and it cannot use component pouches or spellcasting foci for Material component requirements.

## At higher levels

The radius increases by 10 feet for each spell slot level above 2.
