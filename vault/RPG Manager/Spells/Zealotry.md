---
rpg_manager_id: 83
rpg_manager_kind: "spells"
name: "Zealotry"
id: "zealotry"
level: 3
range:
  type: "ranged"
  distanceFeet: 30
school: "transmutation"
tagIds: []
classIds:
  - 2
  - 5
  - 6
  - 7
duration:
  type: "oneMinute"
  concentration: true
attackType: "none"
components:
  verbal: true
  somatic: true
  material: true
  materialConsumed: false
  materialDescription: "a piece of red cloth"
sourcePage: 5
castingTime:
  unit: "action"
  amount: 1
savingThrow: "none"
sourceFileId: 1
---

Choose a willing creature that you can see within range. The target gains an additional action on each of its turns, which can be used to take only the Attack (one attack only) or Dash action, and it gains Resistance to [[RPG Manager/Damage Types/Fire]] and [[RPG Manager/Damage Types/Radiant]] damage. Additionally, when the target hits a creature with an attack, it can deal an additional 2d6 [[RPG Manager/Damage Types/Fire]] or [[RPG Manager/Damage Types/Radiant]] damage (its choice for each attack), up to once per turn.
During the spell, whenever the target would make a Wisdom or Charisma saving throw, it can take 2d6 [[RPG Manager/Damage Types/Fire]] damage to make it with Advantage.
