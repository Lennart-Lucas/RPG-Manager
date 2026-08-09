---
rpg_manager_id: 178
rpg_manager_kind: "spells"
name: "Cacophonic Call"
id: "cacophonic-call"
level: 7
school: "evocation"
castingTime:
  amount: 1
  unit: "action"
range:
  type: "self"
components:
  verbal: true
  somatic: false
  material: false
  materialConsumed: false
duration:
  type: "oneRound"
  concentration: false
classIds:
  - 3
  - 5
  - 10
tagIds: []
savingThrow: "none"
attackType: "none"
sourceFileId: 12
sourcePage: 19
---

You unleash an ululating scream that radiates from you in a 30-foot radius emanation. The scream can be heard up to 1,000 feet away. Each creature of your choice in the area must make a Constitution or Wisdom saving throw (its choice).
Successful Constitution Save. The creature takes 4d8 [[RPG Manager/Damage Types/Psychic]] damage and is [[RPG Manager/Conditions/Frightened]] of you until the start of your next turn. While [[RPG Manager/Conditions/Frightened]] in this way, it can only cast spells of 1st level or lower.
Successful Wisdom Save. The creature takes 4d8 [[RPG Manager/Damage Types/Thunder]] damage and is [[RPG Manager/Conditions/Dazed]] until the start of your next turn.
Failed Save (Either Type). The creature suffers both of the above effects.

## At higher levels

Both the [[RPG Manager/Damage Types/Thunder]] and [[RPG Manager/Damage Types/Psychic]] damage increases by 1d8 for each slot level above 7th.
