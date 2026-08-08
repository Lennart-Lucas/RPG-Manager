---
rpg_manager_id: 81
rpg_manager_kind: "spells"
name: "Ordinance of Obliteration"
id: "ordinance-of-obliteration"
level: 5
school: "evocation"
castingTime:
  amount: 1
  unit: "action"
range:
  type: "ranged"
  distanceFeet: 300
components:
  verbal: true
  somatic: true
  material: true
  materialDescription: "a piece of sunstone"
  materialConsumed: false
duration:
  type: "oneMinute"
  concentration: true
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

You shed Bright Light in a 30-foot radius, and Dim Light for an additional 30 feet.
When you cast the spell, and as a Magic Action on each of your turns thereafter, you can manifest a Medium spear of resplendent flame to launch at a point or creature within range. If a creature was chosen, make a ranged spell attack. If the target is more than 120 feet away, the attack is made with Disadvantage. On a hit, the target takes 5d6 [[RPG Manager/Damage Types/Piercing]] or [[RPG Manager/Damage Types/Fire]] damage (your choice for each attack).
Whether the attack hits or misses, the spear erupts in a 10-foot Emanation at the chosen point or target's space. Each creature in the Emanation makes a Constitution saving throw, taking 5d6 [[RPG Manager/Damage Types/Radiant]] damage on a failed save, or half as much damage on a successful one.

## At higher levels

The [[RPG Manager/Damage Types/Piercing]] or [[RPG Manager/Damage Types/Fire]] damage and [[RPG Manager/Damage Types/Radiant]] damage increase by 1d6 for each spell slot level above 5.
