---
rpg_manager_id: 76
rpg_manager_kind: "spells"
name: "Sanctioned Smite"
id: "sanctioned-smite"
level: 1
school: "enchantment"
castingTime:
  amount: 1
  unit: "bonus action"
range:
  type: "ranged"
  distanceFeet: 60
components:
  verbal: true
  somatic: false
  material: false
  materialConsumed: false
duration:
  type: "oneMinute"
  concentration: false
classIds:
  - 2
  - 7
tagIds: []
savingThrow: "none"
attackType: "none"
sourceFileId: 1
sourcePage: 2
---

## Description

Choose a willing creature you can see within range. The target's Melee weapons or hands glow for the spell's duration. While glowing, the next time the target hits a creature with a Melee weapon attack or Unarmed Strike, the glow erupts in a 10-foot-radius Sphere centred on the creature hit, then the spell ends. Each creature in the Sphere makes a Constitution saving throw, taking 3d8 [[RPG Manager/Damage Types/Radiant]] damage on a failed save, or half as much damage on a successful one. The spell's target has Advantage on this spell's saving throw.

## At higher levels

The damage increases by 1d8 for each spell slot level above 1.
