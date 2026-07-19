/// Keep in sync with [backend/app/data/default_skills.py].
class DefaultSkill {
  const DefaultSkill({required this.name, required this.attribute});

  final String name;
  final String attribute;
}

const defaultSkills = <DefaultSkill>[
  DefaultSkill(name: 'Athletics', attribute: 'STR'),
  DefaultSkill(name: 'Acrobatics', attribute: 'DEX'),
  DefaultSkill(name: 'Sleight of Hand', attribute: 'DEX'),
  DefaultSkill(name: 'Stealth', attribute: 'DEX'),
  DefaultSkill(name: 'Arcana', attribute: 'INT'),
  DefaultSkill(name: 'History', attribute: 'INT'),
  DefaultSkill(name: 'Investigation', attribute: 'INT'),
  DefaultSkill(name: 'Nature', attribute: 'INT'),
  DefaultSkill(name: 'Religion', attribute: 'INT'),
  DefaultSkill(name: 'Animal Handling', attribute: 'WIS'),
  DefaultSkill(name: 'Insight', attribute: 'WIS'),
  DefaultSkill(name: 'Medicine', attribute: 'WIS'),
  DefaultSkill(name: 'Perception', attribute: 'WIS'),
  DefaultSkill(name: 'Survival', attribute: 'WIS'),
  DefaultSkill(name: 'Deception', attribute: 'CHA'),
  DefaultSkill(name: 'Intimidation', attribute: 'CHA'),
  DefaultSkill(name: 'Performance', attribute: 'CHA'),
  DefaultSkill(name: 'Persuasion', attribute: 'CHA'),
];
