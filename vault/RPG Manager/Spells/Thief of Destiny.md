---
rpg_manager_id: 52
rpg_manager_kind: "spells"
name: "Thief of Destiny"
id: "thief-of-destiny"
level: 5
school: "divination"
castingTime:
  amount: 1
  unit: "action"
range:
  type: "ranged"
  distanceFeet: 90
components:
  verbal: true
  somatic: true
  material: true
  materialDescription: "a coin with two tails sides"
  materialConsumed: false
duration:
  type: "oneMinute"
  concentration: true
classIds:
  - 10
tagIds:
  - 62
savingThrow: "none"
attackType: "none"
sourceFileId: 4
sourcePage: 2
---

Choose a creature you can see within range. It must succeed a charisma saving throw or, by your magic, you twist and bend the course of its destiny, cursing it with a promise of failure.
Once per turn for the duration of that spell, when your target makes an attack roll, an ability check or a saving throw, you can choose to also roll a d20. If your result is higher than the score of its d20, your target fails its roll.
In addition, when a feature or a spell requires you to target a creature affected by the Hex spell (such as the Maddening Hex Eldritch Invocation), it also works against a creature affected by that spell.
