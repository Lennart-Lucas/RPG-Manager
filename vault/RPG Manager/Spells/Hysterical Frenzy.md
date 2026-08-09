---
rpg_manager_id: 183
rpg_manager_kind: "spells"
name: "Hysterical Frenzy"
id: "hysterical-frenzy"
level: 5
school: "enchantment"
castingTime:
  amount: 1
  unit: "action"
range:
  type: "ranged"
  distanceFeet: 90
components:
  verbal: true
  somatic: true
  material: false
  materialConsumed: false
duration:
  type: "oneMinute"
  concentration: true
classIds:
  - 3
  - 5
  - 6
tagIds: []
savingThrow: "none"
attackType: "none"
sourceFileId: 12
sourcePage: 19
---

You unleash a torrent of overwhelming emotion—blending agony and euphoria into a maddening storm. Each creature in a 20-foot-radius sphere centered on a point you can see within range must make a Wisdom saving throw (a creature can choose to fail).
On a failed save, a creature is affected by the [[RPG Manager/Conditions/Rampaging]] condition for the duration. At the end of each of its turns, the creature can repeat the saving throw, ending the effect on a success. The creature has disadvantage on this saving throw if it damaged another creature with an attack during that turn.

## At higher levels

The sphere's radius increases by 5 feet for each slot level above 5th.
