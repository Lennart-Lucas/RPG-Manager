import '../../auth/data/auth_api.dart';
import '../../auth/state/auth_controller.dart';
import '../../player_options/races/data/race_model.dart';
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

final Map<String, Future<CatalogItem?>> _resolveInFlight = {};
final Map<String, CatalogItem?> _resolveCache = {};
final Map<String, Future<CatalogEmbedContent?>> _embedInFlight = {};
final Map<String, CatalogEmbedContent?> _embedCache = {};
final Map<String, Future<String?>> _labelInFlight = {};
final Map<String, String?> _labelCache = {};

String _cacheKey(String kindApi, String target) =>
    '${kindApi.toLowerCase()}\u0000${target.trim().toLowerCase()}';

/// Resolve a wiki `kind` + target (numeric id, or legacy name) to a [CatalogItem].
Future<CatalogItem?> resolveCatalogItemByWikiRef({
  required AuthController auth,
  required String kindApiValue,
  required String target,
  CatalogApi? api,
}) async {
  final kind = CatalogKind.tryParseApiValue(kindApiValue) ??
      CatalogKind.tryParseApiValue(kindApiValue.replaceAll('-', '_'));
  if (kind == null) return null;

  final key = _cacheKey(kind.apiValue, target);
  if (_resolveCache.containsKey(key)) {
    return _resolveCache[key];
  }
  final inFlight = _resolveInFlight[key];
  if (inFlight != null) return inFlight;

  final future = _resolveCatalogItemByWikiRefUncached(
    auth: auth,
    kind: kind,
    target: target,
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

/// Live display name for a wiki target (alias should be preferred by callers).
Future<String?> resolveCatalogWikiLinkLabel({
  required AuthController auth,
  required String kindApiValue,
  required String target,
  CatalogApi? api,
}) async {
  final key = _cacheKey(kindApiValue, target);
  if (_labelCache.containsKey(key)) return _labelCache[key];
  final inFlight = _labelInFlight[key];
  if (inFlight != null) return inFlight;

  final future = () async {
    final item = await resolveCatalogItemByWikiRef(
      auth: auth,
      kindApiValue: kindApiValue,
      target: target,
      api: api,
    );
    return item?.name;
  }();
  _labelInFlight[key] = future;
  try {
    final name = await future;
    _labelCache[key] = name;
    return name;
  } finally {
    _labelInFlight.remove(key);
  }
}

Future<CatalogItem?> _resolveCatalogItemByWikiRefUncached({
  required AuthController auth,
  required CatalogKind kind,
  required String target,
  required CatalogApi api,
}) async {
  final token = await auth.requireAccessToken();
  if (token == null) return null;

  final trimmed = target.trim();
  if (trimmed.isEmpty) return null;

  try {
    final asId = int.tryParse(trimmed);
    if (asId != null) {
      try {
        return await api.get(token, kind, asId);
      } on AuthApiException {
        return null;
      }
    }

    final results = await api.search(token, query: trimmed);
    final needle = trimmed.toLowerCase();
    for (final item in results) {
      if (item.kind == kind.apiValue && item.name.toLowerCase() == needle) {
        return api.get(token, kind, item.id);
      }
    }
    for (final item in results) {
      if (item.kind == kind.apiValue &&
          item.name.toLowerCase().contains(needle)) {
        return api.get(token, kind, item.id);
      }
    }

    final listed = await api.list(token, kind);
    for (final item in listed) {
      if (item.name.toLowerCase() == needle) return item;
    }
    if (kind == CatalogKind.locations) {
      for (final item in listed) {
        final record = LocationRecord.fromCatalogPayload(
          name: item.name,
          payload: item.payload,
        );
        if (record.matchesNameOrAlias(needle)) return item;
      }
    }
    if (kind == CatalogKind.organisations) {
      for (final item in listed) {
        final record = OrganisationRecord.fromCatalogPayload(
          name: item.name,
          payload: item.payload,
        );
        if (record.matchesNameOrAlias(needle)) return item;
      }
    }
    if (kind == CatalogKind.races) {
      for (final item in listed) {
        final record = RaceRecord.fromCatalogPayload(
          name: item.name,
          payload: item.payload,
        );
        if (record.matchesNameOrAlias(needle)) return item;
      }
    }
    return null;
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
  required String target,
  String? alias,
  CatalogApi? api,
}) async {
  final key = _cacheKey(kindApiValue, target);
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
      target: target,
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
