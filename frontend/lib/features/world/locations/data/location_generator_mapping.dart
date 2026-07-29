/// Maps generator output field names onto [LocationRecord] payload keys
/// for a future "apply generator → location" step. Not auto-persisted.
const locationGeneratorFieldMapping = <String, String>{
  'name': 'name',
  'type': 'type',
  'description': 'description',
  'population': 'population',
  'government': 'government',
  'ruler': 'ruler',
  'alignment': 'alignment',
  'religions': 'religions',
  'languages': 'languages',
  'exports': 'exports',
  'imports': 'imports',
  'defenses': 'defenses',
  'history': 'history',
  'map_notes': 'mapNotes',
  'mapNotes': 'mapNotes',
  'parent': 'parentId',
};
