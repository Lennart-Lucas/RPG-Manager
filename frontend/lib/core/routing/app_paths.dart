import '../../features/catalog/data/catalog_kind.dart';
import '../../features/shell/app_page.dart';

/// Flat path helpers for go_router (`/characters`, `/characters/42`).
abstract final class AppPaths {
  static const home = '/';
  static const login = '/login';
  static const register = '/register';
  static const preferences = '/preferences';

  static const loginFromParam = 'from';

  /// Path segment for a catalog kind (`creature_types` → `creature-types`).
  static String kindSegment(CatalogKind kind) =>
      kind.apiValue.replaceAll('_', '-');

  static CatalogKind? kindFromSegment(String segment) {
    final normalized = segment.trim().toLowerCase().replaceAll('-', '_');
    return CatalogKind.tryParseApiValue(normalized);
  }

  static String catalogList(CatalogKind kind) => '/${kindSegment(kind)}';

  static String catalogDetail(CatalogKind kind, int id) =>
      '/${kindSegment(kind)}/$id';

  static String page(AppPage page) => switch (page) {
        AppPage.home => home,
        AppPage.preferences => preferences,
        AppPage.generator => '/generators',
        AppPage.resources => '/resources',
        AppPage.mapMaker => '/map-maker',
        AppPage.playlists => '/playlists',
        AppPage.classes => catalogList(CatalogKind.classes),
        AppPage.feats => catalogList(CatalogKind.feats),
        AppPage.items => catalogList(CatalogKind.items),
        AppPage.languages => catalogList(CatalogKind.languages),
        AppPage.races => catalogList(CatalogKind.races),
        AppPage.transformations => catalogList(CatalogKind.transformations),
        AppPage.skills => catalogList(CatalogKind.skills),
        AppPage.spells => catalogList(CatalogKind.spells),
        AppPage.conditions => catalogList(CatalogKind.conditions),
        AppPage.damageTypes => catalogList(CatalogKind.damageTypes),
        AppPage.itemProperties => catalogList(CatalogKind.itemProperties),
        AppPage.rules => catalogList(CatalogKind.rules),
        AppPage.spellTags => catalogList(CatalogKind.spellTags),
        AppPage.features => catalogList(CatalogKind.features),
        AppPage.creatures => catalogList(CatalogKind.creatures),
        AppPage.atlas => catalogList(CatalogKind.locations),
        AppPage.characters => catalogList(CatalogKind.characters),
        AppPage.organisations => catalogList(CatalogKind.organisations),
        AppPage.events => catalogList(CatalogKind.events),
        AppPage.story => catalogList(CatalogKind.campaigns),
      };

  /// Maps a location path to the sidebar [AppPage], if any.
  static AppPage? pageFromPath(String path) {
    final normalized = _normalizePath(path);
    if (normalized == home || normalized.isEmpty) return AppPage.home;
    if (normalized == preferences) return AppPage.preferences;
    if (normalized == '/generators' || normalized == '/generator') {
      return AppPage.generator;
    }
    if (normalized == '/resources') return AppPage.resources;
    if (normalized == '/map-maker') return AppPage.mapMaker;
    if (normalized == '/playlists') return AppPage.playlists;

    // Strip detail id: /characters/42 → /characters
    final listPath = _listPathOf(normalized);
    for (final page in AppPage.values) {
      if (page == AppPage.home || page == AppPage.preferences) continue;
      if (_normalizePath(AppPaths.page(page)) == listPath) return page;
    }
    return null;
  }

  static bool isAuthPath(String path) {
    final n = _normalizePath(path);
    return n == login || n == register;
  }

  static bool isDmToolPath(String path) {
    final page = pageFromPath(path);
    return page == AppPage.generator ||
        page == AppPage.resources ||
        page == AppPage.mapMaker ||
        page == AppPage.playlists;
  }

  static String loginWithReturn(String from) {
    final encoded = Uri.encodeComponent(from);
    return '$login?$loginFromParam=$encoded';
  }

  static String? returnPathFromLogin(Uri uri) {
    final raw = uri.queryParameters[loginFromParam];
    if (raw == null || raw.isEmpty) return null;
    final decoded = Uri.decodeComponent(raw);
    if (!decoded.startsWith('/') || isAuthPath(decoded)) return null;
    return decoded;
  }

  static String _normalizePath(String path) {
    if (path.isEmpty) return home;
    var p = path.split('?').first.split('#').first;
    if (p.length > 1 && p.endsWith('/')) {
      p = p.substring(0, p.length - 1);
    }
    return p.isEmpty ? home : p;
  }

  static String _listPathOf(String normalized) {
    final parts = normalized.split('/').where((s) => s.isNotEmpty).toList();
    if (parts.length >= 2 && int.tryParse(parts.last) != null) {
      return '/${parts.sublist(0, parts.length - 1).join('/')}';
    }
    return normalized;
  }
}
