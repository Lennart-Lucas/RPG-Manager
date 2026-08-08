import '../../auth/data/auth_api.dart';
import '../../auth/state/auth_controller.dart';
import '../../world/locations/data/location_model.dart';
import '../../world/organisations/data/organisation_model.dart';
import 'catalog_api.dart';
import 'catalog_kind.dart';
import 'catalog_models.dart';
import 'catalog_primary_body.dart';

class CatalogEmbedContent {
  const CatalogEmbedContent({
    required this.kind,
    required this.name,
    required this.title,
    required this.body,
  });

  final String kind;
  final String name;
  final String title;
  final String body;
}

class _WikiMatch {
  const _WikiMatch({
    required this.id,
    required this.kind,
    required this.name,
  });

  final int id;
  final String kind;
  final String name;
}

final Map<String, Future<CatalogItem?>> _resolveInFlight = {};
final Map<String, CatalogItem?> _resolveCache = {};
final Map<String, Future<CatalogEmbedContent?>> _embedInFlight = {};
final Map<String, CatalogEmbedContent?> _embedCache = {};

String _cacheKey(String kindApi, String name) =>
    '${kindApi.toLowerCase()}\u0000${name.trim().toLowerCase()}';

/// Resolve a wiki kind+name to a full [CatalogItem] (with payload).
Future<CatalogItem?> resolveCatalogItemByWikiRef({
  required AuthController auth,
  required String kindApiValue,
  required String name,
  CatalogApi? api,
}) async {
  final kind = CatalogKind.tryParseApiValue(kindApiValue) ??
      CatalogKind.tryParseApiValue(kindApiValue.replaceAll('-', '_'));
  if (kind == null) return null;

  final key = _cacheKey(kind.apiValue, name);
  if (_resolveCache.containsKey(key)) {
    return _resolveCache[key];
  }
  final inFlight = _resolveInFlight[key];
  if (inFlight != null) return inFlight;

  final future = _resolveCatalogItemByWikiRefUncached(
    auth: auth,
    kind: kind,
    name: name,
    api: api ?? CatalogApi(),
  );
  _resolveInFlight[key] = future;
  try {
    final item = await future;
    _resolveCache[key] = item;
    return item;
  } finally {
    _resolveInFlight.remove(key);
  }
}

Future<CatalogItem?> _resolveCatalogItemByWikiRefUncached({
  required AuthController auth,
  required CatalogKind kind,
  required String name,
  required CatalogApi api,
}) async {
  final token = await auth.requireAccessToken();
  if (token == null) return null;

  try {
    final results = await api.search(token, query: name);
    _WikiMatch? match;
    final needle = name.trim().toLowerCase();
    for (final item in results) {
      if (item.kind == kind.apiValue && item.name.toLowerCase() == needle) {
        match = _WikiMatch(
          id: item.id,
          kind: item.kind,
          name: item.name,
        );
        break;
      }
    }
    if (match == null) {
      for (final item in results) {
        if (item.kind == kind.apiValue &&
            item.name.toLowerCase().contains(needle)) {
          match = _WikiMatch(
            id: item.id,
            kind: item.kind,
            name: item.name,
          );
          break;
        }
      }
    }
    if (match == null) {
      final listed = await api.list(token, kind);
      for (final item in listed) {
        if (item.name.toLowerCase() == needle) {
          match = _WikiMatch(
            id: item.id,
            kind: item.kind.apiValue,
            name: item.name,
          );
          break;
        }
      }
      if (match == null && kind == CatalogKind.locations) {
        for (final item in listed) {
          final record = LocationRecord.fromCatalogPayload(
            name: item.name,
            payload: item.payload,
          );
          if (record.matchesNameOrAlias(needle)) {
            match = _WikiMatch(
              id: item.id,
              kind: item.kind.apiValue,
              name: item.name,
            );
            break;
          }
        }
      }
      if (match == null && kind == CatalogKind.organisations) {
        for (final item in listed) {
          final record = OrganisationRecord.fromCatalogPayload(
            name: item.name,
            payload: item.payload,
          );
          if (record.matchesNameOrAlias(needle)) {
            match = _WikiMatch(
              id: item.id,
              kind: item.kind.apiValue,
              name: item.name,
            );
            break;
          }
        }
      }
      // Prefer full payload from list when we already have it.
      if (match != null) {
        for (final item in listed) {
          if (item.id == match.id) return item;
        }
      }
    }
    if (match == null) return null;
    return api.get(token, kind, match.id);
  } on AuthApiException {
    return null;
  } catch (_) {
    return null;
  }
}

/// Resolve an embed to title + primary body (cached).
Future<CatalogEmbedContent?> resolveCatalogEmbed({
  required AuthController auth,
  required String kindApiValue,
  required String name,
  String? alias,
  CatalogApi? api,
}) async {
  final key = _cacheKey(kindApiValue, name);
  if (_embedCache.containsKey(key)) {
    final cached = _embedCache[key];
    if (cached == null) return null;
    if (alias != null && alias.isNotEmpty && cached.title != alias) {
      return CatalogEmbedContent(
        kind: cached.kind,
        name: cached.name,
        title: alias,
        body: cached.body,
      );
    }
    return cached;
  }
  final inFlight = _embedInFlight[key];
  if (inFlight != null) {
    final content = await inFlight;
    if (content == null) return null;
    if (alias != null && alias.isNotEmpty) {
      return CatalogEmbedContent(
        kind: content.kind,
        name: content.name,
        title: alias,
        body: content.body,
      );
    }
    return content;
  }

  final future = () async {
    final item = await resolveCatalogItemByWikiRef(
      auth: auth,
      kindApiValue: kindApiValue,
      name: name,
      api: api,
    );
    if (item == null) return null;
    return CatalogEmbedContent(
      kind: item.kind.apiValue,
      name: item.name,
      title: (alias != null && alias.isNotEmpty) ? alias : item.name,
      body: catalogPrimaryBody(item),
    );
  }();
  _embedInFlight[key] = future;
  try {
    final content = await future;
    _embedCache[key] = content;
    return content;
  } finally {
    _embedInFlight.remove(key);
  }
}
