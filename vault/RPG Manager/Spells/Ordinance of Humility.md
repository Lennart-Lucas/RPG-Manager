---
rpg_manager_id: 79
rpg_manager_kind: "spells"
name: "Ordinance of Humility"
id: "ordinance-of-humility"
level: 3
school: "evocation"
castingTime:
  amount: 1
  unit: "action"
range:
  type: "ranged"
  distanceFeet: 120
components:
  verbal: true
  somatic: false
  material: true
  materialDescription: "a bell"
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
sourcePage: 4
---

## Description

You project one word in a 20-foot-radius Sphere centred on a point you choose within range. Each creature in the Sphere makes a Constitution saving throw. On a failed save, a creature takes 3d8 [[RPG Manager/Damage Types/Thunder]] damage and is knocked [[RPG Manager/Conditions/Prone]]. On a successful save, a creature takes half as much damage only.
If this spell causes a creature to make a Constitution saving throw to maintain Concentration, it is made with Disadvantage.
Echoes of the projected word are audible within 300 feet. Fiends have Disadvantage on saving throws for this spell.

## At higher levels

The damage increases by 1d8 for each spell slot level above 3.
