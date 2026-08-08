---
rpg_manager_id: 19
rpg_manager_kind: "spells"
name: "Glamour Veil"
id: "glamour-veil"
level: 1
range:
  type: "self"
school: "enchantment"
tagIds: []
classIds:
  - 3
  - 5
  - 6
  - 8
  - 10
duration:
  type: "tenMinutes"
  concentration: true
attackType: "none"
components:
  verbal: true
  somatic: true
  material: true
  materialCostGp: 50.0
  materialConsumed: false
  materialDescription: "a carving of an elephant worth at least 50 gp"
sourcePage: 79
castingTime:
  unit: "action"
  amount: 1
savingThrow: "none"
sourceFileId: 2
---

You surround yourself in distracting magic that shrouds you from those who haven't yet noticed you. You become [[RPG Manager/Conditions/Invisible]] to each creature that you are hidden from. You remain [[RPG Manager/Conditions/Invisible]] to each creature until you are no longer hidden from it or the spell ends. Undead and creatures that can't be charmed are unaffected by the spell.
The spell ends if you attack or cast a spell.
