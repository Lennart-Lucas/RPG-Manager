import 'catalog_kind.dart';

class CatalogItem {
  const CatalogItem({
    required this.id,
    required this.userId,
    required this.kind,
    required this.name,
    this.payload,
  });

  final int id;
  final int userId;
  final CatalogKind kind;
  final String name;
  final Map<String, dynamic>? payload;

  factory CatalogItem.fromJson(Map<String, dynamic> json) {
    final rawPayload = json['payload'];
    return CatalogItem(
      id: json['id'] as int,
      userId: json['user_id'] as int,
      kind: CatalogKind.values.firstWhere(
        (value) => value.apiValue == json['kind'],
      ),
      name: json['name'] as String,
      payload: rawPayload is Map<String, dynamic>
          ? rawPayload
          : rawPayload is Map
              ? Map<String, dynamic>.from(rawPayload)
              : null,
    );
  }
}
