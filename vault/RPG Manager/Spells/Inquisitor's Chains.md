---
rpg_manager_id: 75
rpg_manager_kind: "spells"
name: "Inquisitor's Chains"
id: "inquisitor-s-chains"
level: 1
school: "conjuration"
castingTime:
  amount: 1
  unit: "action"
range:
  type: "ranged"
  distanceFeet: 60
components:
  verbal: true
  somatic: true
  material: true
  materialDescription: "a piece of silver chain"
  materialConsumed: false
duration:
  type: "oneMinute"
  concentration: true
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
sourcePage: 2
---

## Description

Chains of celestial steel burst from under a creature you choose and can see within range. The target must succeed on a Strength saving throw or be [[RPG Manager/Conditions/Restrained]] by the chains. Fiends have Disadvantage on saving throws for this spell.
If a creature attempts to teleport the target, including itself, that creature must succeed on an ability check using their spellcasting ability against your spell save DC, or the teleport fails. If the teleport is from a spell of a level higher than the chains', the creature makes the check with Advantage. Creatures without a spellcasting ability make an Intelligence (Arcana) check instead.
A [[RPG Manager/Conditions/Restrained]] creature can take an action to make a Strength (Athletics) check against your spell save DC, ending this spell on itself on a success.

## At higher levels

You can target one additional creature for each spell slot level above 1.
