---
rpg_manager_id: 66
rpg_manager_kind: "spells"
name: "Buzzing Blade"
id: "buzzing-blade"
level: 0
school: "transmutation"
castingTime:
  amount: 1
  unit: "bonus action"
range:
  type: "self"
components:
  verbal: true
  somatic: true
  material: true
  materialDescription: "a melee weapon that deals piercing damage worth at least 1sp"
  materialCostGp: 0.05
  materialConsumed: false
duration:
  type: "oneRound"
  concentration: false
classIds:
  - 4
  - 5
  - 6
tagIds: []
savingThrow: "none"
attackType: "none"
sourceFileId: 5
sourcePage: 1
---

## Description

You brandish the weapon used in the spell's casting and make a melee attack with it against one creature within 5 feet of you, with all the power of an angry swarm of hornets. On a hit, the target suffers the weapon attack's normal effects and it takes 2d4 [[RPG Manager/Damage Types/Poison]] damage the next time it uses its reaction before the end of your next turn.

## At higher levels

At 5th level, the attack deals an extra 2d4 [[RPG Manager/Damage Types/Poison]] damage and the [[RPG Manager/Damage Types/Poison]] damage dealt on a target's reaction increases by 2d4 (to a total of 4d4). Both [[RPG Manager/Damage Types/Poison]] damages then increase by 2d4 when you reach 11th level (4d4 and 6d4), and again when you reach 17th level (6d4 and 8d4).
