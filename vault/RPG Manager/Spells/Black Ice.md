---
rpg_manager_id: 45
rpg_manager_kind: "spells"
name: "Black Ice"
id: "black-ice"
level: 4
range:
  type: "ranged"
  distanceFeet: 120
school: "evocation"
tagIds: []
classIds:
  - 10
duration:
  type: "oneMinute"
  concentration: true
attackType: "none"
components:
  verbal: true
  somatic: true
  material: true
  materialConsumed: false
  materialDescription: "an ice cube and a drop of ink"
sourcePage: 2
castingTime:
  unit: "action"
  amount: 1
savingThrow: "none"
sourceFileId: 4
---

A magical black ice starts spreading from a point you choose within range and tries to cover any creature within 20 feet of that point. Creatures in this area must succeed a Dexterity saving throw, or be covered by the [[RPG Manager/Damage Types/Necrotic]] frost. While covered by the black ice, a creature takes 2d8 [[RPG Manager/Damage Types/Cold]] damage on the start of each of its turns, and takes 2d8 [[RPG Manager/Damage Types/Necrotic]] damage when it moves for the first time of a turn (willingly or not).
A creature covered by the black ice can make a Constitution saving throw at the end of each of its turns, ending the spell on itself on a success.

## At higher levels

When you cast this spell with a 5th level spell slot or higher, the [[RPG Manager/Damage Types/Cold]] and the [[RPG Manager/Damage Types/Necrotic]] damage both increase to 3d8.
