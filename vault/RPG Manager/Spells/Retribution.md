---
rpg_manager_id: 82
rpg_manager_kind: "spells"
name: "Retribution"
id: "retribution"
level: 2
school: "evocation"
castingTime:
  amount: 1
  unit: "reaction"
  reactionTrigger: "which you take when you see an enemy within range deal damage to you or your ally"
range:
  type: "ranged"
  distanceFeet: 60
components:
  verbal: true
  somatic: true
  material: false
  materialConsumed: false
duration:
  type: "oneRound"
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

You create a sword of light that hangs above the creature that damaged you or your ally, and which follows that creature for the spell's duration. The sword stores damage equal to the amount that triggered this spell plus any damage the target deals during the spell's duration, up to a maximum of 20.
At the end of the target's next turn, or when the sword reaches its maximum stored damage, the target makes a Constitution saving throw as the sword plunges into them, then the spell ends. On a failure, the target takes [[RPG Manager/Damage Types/Radiant]] damage equal to the amount stored, or half as much damage on a success.

## At higher levels

The sword can store up to 5 additional damage for each spell slot level above 2.
