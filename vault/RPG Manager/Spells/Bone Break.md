---
rpg_manager_id: 17
rpg_manager_kind: "spells"
name: "Bone Break"
id: "bone-break"
level: 2
school: "necromancy"
castingTime:
  amount: 1
  unit: "action"
range:
  type: "ranged"
  distanceFeet: 30
components:
  verbal: true
  somatic: true
  material: false
  materialConsumed: false
duration:
  type: "oneRound"
  concentration: false
classIds:
  - 5
  - 6
  - 10
tagIds: []
savingThrow: "none"
attackType: "none"
sourceFileId: 2
sourcePage: 71
---

## Description

Dark magic suffuses your hand in an attempt to crush the bones of one creature that you can see within range. The target must make a Constitution saving throw. On a failed saving throw, the target takes 2d6 [[RPG Manager/Damage Types/Bludgeoning]] damage and 2d6 [[RPG Manager/Damage Types/Necrotic]] damage, and until the end of its next turn, its speed is halved and it has disadvantage on weapon attacks. On a successful save, it takes half as much damage and suffers no other effects.
If the target is undead, it has disadvantage on the saving throw, the spell ignores resistance to [[RPG Manager/Damage Types/Necrotic]] damage, and it knocks the target prone on a failed save.

## At higher levels

When you cast this spell using a spell slot of 3rd level or higher, the [[RPG Manager/Damage Types/Bludgeoning]] damage increases by ld6 for each slot level above 2nd
