---
rpg_manager_id: 182
rpg_manager_kind: "spells"
name: "Chaotic Pavanne"
id: "chaotic-pavanne"
level: 3
school: "enchantment"
castingTime:
  amount: 1
  unit: "action"
range:
  type: "ranged"
  distanceFeet: 30
components:
  verbal: true
  somatic: true
  material: true
  materialDescription: "a bit of catgut"
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

Each creature in a 15-foot cube centered on a point you choose within range must succeed on a Wisdom saving throw or be affected for the duration.
On a failed save, the creature begins a painful, involuntary dance. While dancing, the creature:
- Can't take reactions or bonus actions.
- Must stand up if [[RPG Manager/Conditions/Prone]], spending 5 feet of movement to do so.
- Must take the Dodge action.
- Must immediately use all its movement in a random direction. Roll 1d4 to determine the direction: 1—north, 2—east, 3—south, 4—west.
At the end of each of its turns, the creature repeats the Wisdom saving throw, ending the effect on a success. If it did not move during its turn, it makes the saving throw with advantage. On a successful save, the creature falls [[RPG Manager/Conditions/Prone]] and the effect ends for it.

## At higher levels

The affected creature takes 1d10 [[RPG Manager/Damage Types/Bludgeoning]] damage whenever it moves due to the spell. This damage increases by 1d10 for each slot level above 4th.
