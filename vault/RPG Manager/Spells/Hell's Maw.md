---
rpg_manager_id: 47
rpg_manager_kind: "spells"
name: "Hell's Maw"
id: "hell-s-maw"
level: 8
school: "conjuration"
castingTime:
  amount: 1
  unit: "action"
range:
  type: "ranged"
  distanceFeet: 150
components:
  verbal: true
  somatic: true
  material: true
  materialDescription: "a vial of blood from a recently murdered humanoid"
  materialConsumed: false
duration:
  type: "oneMinute"
  concentration: true
classIds:
  - 10
tagIds: []
savingThrow: "none"
attackType: "none"
sourceFileId: 4
sourcePage: 3
---

## Description

You point at a free space you can see on the ground within range. A 15 foot long and 15 feet wide monstrous maw opens there. The maw is a magical portal leading directly to the plane of a greater evil being, such as a fiend from the nine hells, a fey from the feywild, or an eldritch and sprawling being from the void for instance. It doesn't block the lines of sight but counts as a difficult terrain.
When a creature starts its turn within 30 feet of the maw, it must succeed a charisma saving throw, or be [[RPG Manager/Conditions/Frightened]] of the maw until the start of its next turn.
In addition, if a Huge or smaller creature fails that saving throw, it is also pulled 15 feet toward the center of the maw and can't move willingly until the start of its next turn, as it uses all of its speed trying to resist the maw's attraction.
A Huge or smaller creature that ends its turn completely in the space of the maw is transported to the plane of a greater evil being, where it is tortured. At the end of each of its turns, the creature must make a death saving throw. If it succeeds 3 death saving throws before failing 3, or if it rolls a natural 20 on one of its death saving throws, it gets back from that unholy plane and is instantly transported in a free space within 5 feet of the Hell's Maw. It is then immune to the effects of the Hell's Maw for the next 24 hours. If it fails 3 death saving throws before succeeding 3, it dies and its body and soul stay trapped on the evil plane, to be tortured there for eternity (or until it gets resurrected thanks to a wish spell). A critical failure counts as 2 failed death saving throws.
If the spell ends when there are still living creatures in the maw's plane, all those creatures are immediately transported back to your plane, in the closest free space available from where the Hell's Maw was.
