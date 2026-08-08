import '../data/catalog_kind.dart';
import '../data/catalog_models.dart';

/// Primary markdown body for a catalog item (same rules as Obsidian export).
String catalogPrimaryBody(CatalogItem item) {
  final payload = item.payload;
  if (payload == null) return '';
  switch (item.kind) {
    case CatalogKind.features:
      return '${payload['text'] ?? ''}';
    case CatalogKind.creatures:
      return '${payload['trigger'] ?? ''}';
    case CatalogKind.rules:
      return '${payload['body'] ?? payload['description'] ?? ''}';
    case CatalogKind.spells:
      final desc = '${payload['description'] ?? ''}'.trim();
      final higher = payload['higherLevels'];
      if (higher is Map) {
        final higherDesc = '${higher['description'] ?? ''}'.trim();
        if (higherDesc.isNotEmpty) {
          if (desc.isEmpty) return higherDesc;
          return '$desc\n\n## At higher levels\n\n$higherDesc';
        }
      }
      return desc;
    default:
      return '${payload['description'] ?? ''}';
  }
}
