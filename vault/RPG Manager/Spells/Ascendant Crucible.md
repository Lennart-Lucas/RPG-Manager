---
rpg_manager_id: 80
rpg_manager_kind: "spells"
name: "Ascendant Crucible"
id: "ascendant-crucible"
level: 4
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
  type: "tenMinutes"
  concentration: false
attackType: "none"
components:
  verbal: true
  somatic: true
  material: true
  materialConsumed: false
  materialDescription: "a bit of phosphorus"
sourcePage: 4
castingTime:
  unit: "action"
  amount: 1
savingThrow: "none"
sourceFileId: 1
---

Choose a willing creature that you can see within range. For the spell's duration, the target is encircled by snaking streaks of heatless flame shedding Dim Light in a 5-foot Radius. The target can at any point end this spell on itself (no action required).
Each time the target is attacked by an enemy, after a hit or miss, the target and each creature within a 5-foot Emanation makes a Constitution saving throw, as the flames flare. On a failed save, a creature takes 2d8 [[RPG Manager/Damage Types/Fire]] damage, or half as much damage on a successful one.
Once the target is damaged by 3 flares, its Speed increases by 30 feet, and all subsequent flares instead deal [[RPG Manager/Damage Types/Radiant]] damage. Once the target is damaged by 10 flares, it gains 10d8 Temporary Hit Points, and a Fly Speed of 60 feet (hover).
Note: The spell has a 10-ft. Emanation component to its range (creatures within 5-foot Emanation of the target are affected by flares).

## At higher levels

For every 2 spell slot levels above 4, the flare's damage increases by 1d8, and the Temporary Hit Points increase by 5d8.
