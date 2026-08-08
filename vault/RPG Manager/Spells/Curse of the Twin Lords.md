---
rpg_manager_id: 49
rpg_manager_kind: "spells"
name: "Curse of the Twin Lords"
id: "curse-of-the-twin-lords"
level: 4
range:
  type: "ranged"
  distanceFeet: 60
school: "enchantment"
tagIds:
  - 62
classIds:
  - 10
duration:
  type: "tenMinutes"
  concentration: false
attackType: "none"
components:
  verbal: true
  somatic: false
  material: false
  materialConsumed: false
sourcePage: 2
castingTime:
  unit: "action"
  amount: 1
savingThrow: "none"
sourceFileId: 4
---

Choose two hostile creatures of the same size you can see within range. They must make a Charisma saving throw. If both targets fail their saving throw, a spectral and slightly glowing crown appears on both of their heads. If one or both of the targets succeed, the spell fails.
For the spell duration, whenever one of the targets is [[RPG Manager/Conditions/Blinded]], [[RPG Manager/Conditions/Deafened]], [[RPG Manager/Conditions/Incapacitated]], [[RPG Manager/Conditions/Paralyzed]], [[RPG Manager/Conditions/Petrified]], [[RPG Manager/Conditions/Poisoned]], [[RPG Manager/Conditions/Restrained]], or [[RPG Manager/Conditions/Stunned]], the other target is also affected by that same condition until the first target is no longer affected.
Moreover, while under the effect of this spell, if one of the targets should take damage, the second target takes half this amount of damage.
The spell ends if the Dispel Magic spell is used on one of the targets, or if one of the targets dies.
In addition, when a feature or a spell requires you to target a creature affected by the Hex spell (such as the Maddening Hex Eldritch Invocation), it also works against a creature affected by this spell.
