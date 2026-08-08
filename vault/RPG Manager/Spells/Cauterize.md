---
rpg_manager_id: 84
rpg_manager_kind: "spells"
name: "Cauterize"
id: "cauterize"
level: 1
school: "evocation"
castingTime:
  amount: 1
  unit: "bonus action"
range:
  type: "ranged"
  distanceFeet: 30
components:
  verbal: true
  somatic: true
  material: true
  materialDescription: "a match"
  materialConsumed: false
duration:
  type: "instantaneous"
  concentration: false
classIds:
  - 2
  - 4
  - 5
  - 6
  - 7
tagIds: []
savingThrow: "none"
attackType: "none"
sourceFileId: 1
sourcePage: 3
---

## Description

A willing Bloodied creature that you can see within range takes [[RPG Manager/Damage Types/Fire]] or [[RPG Manager/Damage Types/Radiant]] damage (your choice) equal to 1d4 plus your spellcasting ability modifier, and gains Temporary Hit Points equal to three times the damage taken.

## At higher levels

The damage taken increases by 1d4 for each spell slot level above 1.
