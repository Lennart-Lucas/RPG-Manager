---
rpg_manager_id: 86
rpg_manager_kind: "spells"
name: "Penitent's Bane"
id: "penitent-s-bane"
level: 4
range:
  type: "ranged"
  distanceFeet: 90
school: "transmutation"
tagIds: []
classIds:
  - 2
  - 5
  - 6
  - 7
  - 10
duration:
  type: "oneMinute"
  concentration: true
attackType: "none"
components:
  verbal: true
  somatic: true
  material: false
  materialConsumed: false
sourcePage: 5
castingTime:
  unit: "action"
  amount: 1
savingThrow: "none"
sourceFileId: 1
---

Choose one creature you can see within range. The target must succeed on a Constitution saving throw or be affected by the spell for its duration. While marked, the target loses its Resistance to [[RPG Manager/Damage Types/Radiant]] damage, and the first time each turn it takes [[RPG Manager/Damage Types/Radiant]] damage, it takes an extra 2d6 [[RPG Manager/Damage Types/Radiant]] damage.
If the target creature would be dealt [[RPG Manager/Damage Types/Fire]] damage, it is instead dealt an equal amount of [[RPG Manager/Damage Types/Radiant]] damage.

## At higher levels

You can target one additional creature for each spell slot level above 4. The creatures must be within 30 feet of each other when you target them.
