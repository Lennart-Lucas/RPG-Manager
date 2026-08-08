---
rpg_manager_id: 46
rpg_manager_kind: "spells"
name: "Cursed Doll"
id: "cursed-doll"
level: 6
school: "necromancy"
castingTime:
  amount: 10
  unit: "minute"
range:
  type: "touch"
components:
  verbal: true
  somatic: true
  material: true
  materialDescription: "a doll worth at least 500 gp and a lock of hair from your target"
  materialCostGp: 500.0
  materialConsumed: true
duration:
  type: "untilDispelled"
  concentration: false
classIds:
  - 10
tagIds:
  - 62
savingThrow: "none"
attackType: "none"
sourceFileId: 4
sourcePage: 2
---

## Description

You tie the lock of hair of a humanoid to the doll used as component for the spell. For the duration, the soul and the physical body of your target (the creature from which the hair comes) are linked to the doll. As long as the target is on the same plane as the doll, a creature with an Intelligence of 8 or higher that carries the doll can use it to perform the following rites:
• **Spell Targeting:** When you cast a spell while holding the doll in your hand, you can target the creature that is linked to the doll even if it isn't in range, and even if you have no line of sight toward it.
• **Needle Sting (Action):** You can sting the doll with a needle. When you do so, the creature linked to the doll suffers a sudden and intense pain. Its speed is halved until the end of its next turn, and the next time it makes an attack roll, ability check, or saving throw before the end of its next turn, it makes the roll with disadvantage.
• **Feather Tickle (Action):** You can tickle the doll with a feather. When you do so, the creature must succeed on a Constitution saving throw or start laughing uncontrollably until the end of its next turn. While laughing, it falls [[RPG Manager/Conditions/Prone]] and its speed is reduced to 0.
• **Fire Destruction:** If you throw the doll into a [[RPG Manager/Damage Types/Fire]], the target takes 10d10 [[RPG Manager/Damage Types/Fire]] damage and the doll is destroyed.
The spell ends if a Dispel Magic or Remove Curse spell is cast on the doll or on the target, if the hair of the target is removed from the doll, or if the doll is destroyed.
If you use a spell focus, the Wish spell, or any other means to ignore or replace the material components of this spell, the spell fails. It has no effect and you lose your spell slot.
