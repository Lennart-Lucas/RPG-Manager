---
rpg_manager_id: 179
rpg_manager_kind: "spells"
name: "Slashing Shards"
id: "slashing-shards"
level: 4
school: "conjuration"
castingTime:
  amount: 1
  unit: "action"
range:
  type: "ranged"
  distanceFeet: 90
components:
  verbal: true
  somatic: true
  material: true
  materialDescription: "a piece of broken glass"
  materialConsumed: false
duration:
  type: "instantaneous"
  concentration: false
classIds:
  - 5
  - 6
  - 10
tagIds: []
savingThrow: "none"
attackType: "none"
sourceFileId: 12
sourcePage: 21
---

You conjure a cloud of razor-sharp glass and launch it at a creature within range. Make a ranged spell attack against the target. On a hit, the target takes 6d6 [[RPG Manager/Damage Types/Slashing]] damage and must make a Wisdom saving throw. On a failed save, the target takes an additional 6d6 [[RPG Manager/Damage Types/Psychic]] damage, or half as much on a successful one.
If the attack misses, the shards still graze the target, which takes half the [[RPG Manager/Damage Types/Slashing]] damage and suffers no additional effects.

## At higher levels

Both the Slashing and [[RPG Manager/Damage Types/Psychic]] damage increase by 1d6 for each slot level above 4th.
