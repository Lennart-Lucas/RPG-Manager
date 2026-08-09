---
rpg_manager_id: 180
rpg_manager_kind: "spells"
name: "Vicious Lash"
id: "vicious-lash"
level: 1
school: "conjuration"
castingTime:
  amount: 1
  unit: "action"
range:
  type: "ranged"
  distanceFeet: 30
components:
  verbal: true
  somatic: true
  material: false
  materialConsumed: false
duration:
  type: "instantaneous"
  concentration: false
classIds:
  - 3
  - 9
  - 10
tagIds: []
savingThrow: "none"
attackType: "none"
sourceFileId: 12
sourcePage: 21
---

You conjure a whip of raw torment and lash it in a 5-foot-wide line extending from you to a creature within range. Make a melee spell attack against the creature. On a hit, the target takes 2d6 [[RPG Manager/Damage Types/Thunder]] damage.
Hit or miss, the target and each creature in the line between you and it must succeed on a Dexterity saving throw or take 2d6 [[RPG Manager/Damage Types/Psychic]] damage.

## At higher levels

Both the [[RPG Manager/Damage Types/Thunder]] and [[RPG Manager/Damage Types/Psychic]] damage increase by 1d6, and the spell's range increases by 10 feet for each slot level above 1st.
