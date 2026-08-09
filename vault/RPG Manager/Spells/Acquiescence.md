---
rpg_manager_id: 177
rpg_manager_kind: "spells"
name: "Acquiescence"
id: "acquiescence"
level: 2
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
  materialDescription: "A pinch of fine sand, rose petals, or a cricket"
  materialConsumed: false
duration:
  type: "oneMinute"
  concentration: false
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

Choose one creature you can see within range. The target must succeed on a Wisdom saving throw or become [[RPG Manager/Conditions/Drowsy]] for the duration. At the end of each of its turns, the creature can repeat the saving throw, ending the effect on a success.

## At higher levels

You can target one additional creature for each slot level above 2nd.
