import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/state/auth_controller.dart';
import '../../features/auth/ui/home_screen.dart';
import '../../features/auth/ui/login_screen.dart';
import '../../features/auth/ui/register_screen.dart';
import '../../features/catalog/data/catalog_kind.dart';
import '../../features/catalog/ui/catalog_body.dart';
import '../../features/dm_tools/resources/resources_icons.dart';
import '../../features/dm_tools/resources/ui/resources_body.dart';
import '../../features/dm_tools/ui/dm_tool_placeholder_body.dart';
import '../../features/mechanics/conditions/ui/conditions_body.dart';
import '../../features/mechanics/damage_types/ui/damage_types_body.dart';
import '../../features/mechanics/features/ui/features_body.dart';
import '../../features/mechanics/item_properties/ui/item_properties_body.dart';
import '../../features/mechanics/mechanics_icons.dart';
import '../../features/mechanics/spell_tags/ui/spell_tags_body.dart';
import '../../features/player_options/classes/ui/classes_body.dart';
import '../../features/player_options/feats/ui/feats_body.dart';
import '../../features/player_options/items/ui/items_body.dart';
import '../../features/player_options/player_options_icons.dart';
import '../../features/player_options/races/ui/races_body.dart';
import '../../features/player_options/spells/ui/spells_body.dart';
import '../../features/player_options/transformations/ui/transformations_body.dart';
import '../../features/settings/generators/ui/generators_body.dart';
import '../../features/settings/preferences_page.dart';
import '../../features/shell/app_page.dart';
import '../../features/shell/app_shell.dart';
import '../../features/world/campaigns/ui/campaigns_body.dart';
import '../../features/world/characters/ui/characters_body.dart';
import '../../features/world/creatures/ui/creatures_body.dart';
import '../../features/world/events/ui/events_body.dart';
import '../../features/world/locations/ui/locations_body.dart';
import '../../features/world/organisations/ui/organisations_body.dart';
import '../theme/theme_controller.dart';
import 'app_paths.dart';
import 'catalog_detail_loader.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

GoRouter createAppRouter({
  required AuthController auth,
  required ThemeController themeController,
}) {
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: AppPaths.home,
    refreshListenable: auth,
    redirect: (context, state) {
      final status = auth.status;
      final path = state.uri.path;
      final loggingIn = AppPaths.isAuthPath(path);

      if (status == AuthStatus.unknown) {
        return null;
      }

      if (status == AuthStatus.unauthenticated) {
        if (loggingIn) return null;
        return AppPaths.loginWithReturn(state.uri.toString());
      }

      if (loggingIn) {
        return AppPaths.returnPathFromLogin(state.uri) ?? AppPaths.home;
      }

      if (AppPaths.isDmToolPath(path) && !auth.showsDmUi) {
        return AppPaths.home;
      }

      return null;
    },
    routes: [
      GoRoute(
        path: AppPaths.login,
        builder: (context, state) => LoginScreen(
          auth: auth,
          onGoToRegister: () => context.go(AppPaths.register),
        ),
      ),
      GoRoute(
        path: AppPaths.register,
        builder: (context, state) => RegisterScreen(
          auth: auth,
          onGoToLogin: () => context.go(AppPaths.login),
        ),
      ),
      ShellRoute(
        builder: (context, state, child) {
          final page =
              AppPaths.pageFromPath(state.uri.path) ?? AppPage.home;
          return AppShell(
            auth: auth,
            themeController: themeController,
            currentPage: page,
            child: child,
          );
        },
        routes: [
          GoRoute(
            path: AppPaths.home,
            pageBuilder: (context, state) => NoTransitionPage(
              key: state.pageKey,
              child: HomeBody(auth: auth),
            ),
          ),
          GoRoute(
            path: AppPaths.preferences,
            pageBuilder: (context, state) => NoTransitionPage(
              key: state.pageKey,
              child: PreferencesBody(
                auth: auth,
                themeController: themeController,
                onViewAsPlayerEnabled: () {
                  if (AppPaths.isDmToolPath(
                    GoRouterState.of(context).uri.path,
                  )) {
                    context.go(AppPaths.home);
                  }
                },
              ),
            ),
          ),
          GoRoute(
            path: '/resources',
            pageBuilder: (context, state) => NoTransitionPage(
              key: state.pageKey,
              child: ResourcesBody(auth: auth),
            ),
          ),
          GoRoute(
            path: '/map-maker',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: DmToolPlaceholderBody(
                title: 'Map maker',
                icon: mapMakerPageIcon,
              ),
            ),
          ),
          GoRoute(
            path: '/playlists',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: DmToolPlaceholderBody(
                title: 'Playlists',
                icon: playlistsPageIcon,
              ),
            ),
          ),
          _sectionWithDetail(
            auth: auth,
            kind: CatalogKind.generators,
            listBody: GeneratorsBody(auth: auth),
          ),
          ..._catalogSectionRoutes(auth),
        ],
      ),
      // Nested kinds without a top-level sidebar list.
      for (final kind in const [
        CatalogKind.subclasses,
        CatalogKind.sessions,
        CatalogKind.creatureTypes,
      ])
        GoRoute(
          path: '${AppPaths.catalogList(kind)}/:id',
          parentNavigatorKey: rootNavigatorKey,
          builder: (context, state) => CatalogDetailLoaderPage(
            auth: auth,
            kind: kind,
            itemId: int.parse(state.pathParameters['id']!),
          ),
        ),
    ],
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(title: const Text('Not found')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(state.error?.toString() ?? 'Page not found'),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => context.go(AppPaths.home),
              child: const Text('Home'),
            ),
          ],
        ),
      ),
    ),
  );
}

GoRoute _sectionWithDetail({
  required AuthController auth,
  required CatalogKind kind,
  required Widget listBody,
}) {
  return GoRoute(
    path: AppPaths.catalogList(kind),
    pageBuilder: (context, state) => NoTransitionPage(
      key: state.pageKey,
      child: listBody,
    ),
    routes: [
      GoRoute(
        path: ':id',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => CatalogDetailLoaderPage(
          auth: auth,
          kind: kind,
          itemId: int.parse(state.pathParameters['id']!),
        ),
      ),
    ],
  );
}

List<RouteBase> _catalogSectionRoutes(AuthController auth) {
  Widget bodyFor(CatalogKind kind) {
    return switch (kind) {
      CatalogKind.classes => ClassesBody(auth: auth),
      CatalogKind.feats => FeatsBody(auth: auth),
      CatalogKind.items => ItemsBody(auth: auth),
      CatalogKind.languages =>
        CatalogBody(auth: auth, kind: kind, icon: languagesPageIcon),
      CatalogKind.races => RacesBody(auth: auth),
      CatalogKind.transformations => TransformationsBody(auth: auth),
      CatalogKind.skills =>
        CatalogBody(auth: auth, kind: kind, icon: skillsPageIcon),
      CatalogKind.spells => SpellsBody(auth: auth),
      CatalogKind.conditions => ConditionsBody(auth: auth),
      CatalogKind.damageTypes => DamageTypesBody(auth: auth),
      CatalogKind.itemProperties => ItemPropertiesBody(auth: auth),
      CatalogKind.rules =>
        CatalogBody(auth: auth, kind: kind, icon: rulesPageIcon),
      CatalogKind.spellTags => SpellTagsBody(auth: auth),
      CatalogKind.features => FeaturesBody(auth: auth),
      CatalogKind.creatures => CreaturesBody(auth: auth),
      CatalogKind.locations => LocationsBody(auth: auth),
      CatalogKind.characters => CharactersBody(auth: auth),
      CatalogKind.organisations => OrganisationsBody(auth: auth),
      CatalogKind.events => EventsBody(auth: auth),
      CatalogKind.campaigns => CampaignsBody(auth: auth),
      _ => CatalogBody(
          auth: auth,
          kind: kind,
          icon: Icons.article_outlined,
        ),
    };
  }

  const sectionKinds = <CatalogKind>[
    CatalogKind.classes,
    CatalogKind.feats,
    CatalogKind.items,
    CatalogKind.languages,
    CatalogKind.races,
    CatalogKind.transformations,
    CatalogKind.skills,
    CatalogKind.spells,
    CatalogKind.conditions,
    CatalogKind.damageTypes,
    CatalogKind.itemProperties,
    CatalogKind.rules,
    CatalogKind.spellTags,
    CatalogKind.features,
    CatalogKind.creatures,
    CatalogKind.locations,
    CatalogKind.characters,
    CatalogKind.organisations,
    CatalogKind.events,
    CatalogKind.campaigns,
  ];

  return [
    for (final kind in sectionKinds)
      _sectionWithDetail(
        auth: auth,
        kind: kind,
        listBody: bodyFor(kind),
      ),
  ];
}
