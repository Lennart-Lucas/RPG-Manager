import 'catalog_kind.dart';

class CatalogItem {
  const CatalogItem({
    required this.id,
    required this.userId,
    required this.kind,
    required this.name,
  });

  final int id;
  final int userId;
  final CatalogKind kind;
  final String name;

  factory CatalogItem.fromJson(Map<String, dynamic> json) {
    return CatalogItem(
      id: json['id'] as int,
      userId: json['user_id'] as int,
      kind: CatalogKind.values.firstWhere(
        (value) => value.apiValue == json['kind'],
      ),
      name: json['name'] as String,
    );
  }
}
