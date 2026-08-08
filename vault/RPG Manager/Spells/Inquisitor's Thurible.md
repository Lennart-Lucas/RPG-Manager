---
rpg_manager_id: 85
rpg_manager_kind: "spells"
name: "Inquisitor's Thurible"
id: "inquisitor-s-thurible"
level: 3
range:
  type: "self"
school: "conjuration"
tagIds: []
classIds:
  - 2
  - 5
  - 6
  - 7
  - 10
duration:
  type: "tenMinutes"
  concentration: true
attackType: "none"
components:
  verbal: true
  somatic: true
  material: true
  materialConsumed: false
  materialDescription: "incense"
sourcePage: 4
castingTime:
  unit: "bonus action"
  amount: 1
savingThrow: "none"
sourceFileId: 1
---

You summon a thurible of celestial steel that hovers in your space.
As a Magic action, you can make a melee spell attack at a creature within 10 feet, as the thurible whips toward the target. On a hit, the target takes [[RPG Manager/Damage Types/Bludgeoning]] or [[RPG Manager/Damage Types/Radiant]] damage (your choice for each attack) equal to 4d6 plus your spellcasting ability modifier. Fiends take an additional 2d4 [[RPG Manager/Damage Types/Radiant]] damage.
Additionally, unless the target moves at least 20 feet from the space in which it was hit, it cannot cast spells that include a Verbal component until the end of its next turn, as choking smoke follows it.

## At higher levels

The thurible deals an additional 1d6 for each spell slot level above 3.
