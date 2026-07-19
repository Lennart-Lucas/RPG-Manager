import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/ui/markdown_form_field.dart';
import '../../catalog/data/catalog_api.dart';
import '../../catalog/data/catalog_kind.dart';
import '../../catalog/data/catalog_kind_icons.dart';
import '../../catalog/ui/open_catalog_detail.dart';
import '../data/auth_api.dart';
import '../state/auth_controller.dart';

/// Home content shown inside [AppShell] (no own AppBar/drawer).
class HomeBody extends StatefulWidget {
  const HomeBody({super.key, required this.auth});

  final AuthController auth;

  @override
  State<HomeBody> createState() => _HomeBodyState();
}

class _HomeBodyState extends State<HomeBody>
    with SingleTickerProviderStateMixin {
  static const _searchMaxWidth = 584.0;
  static const _layoutDuration = Duration(milliseconds: 420);

  final _api = CatalogApi();
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();
  final _searchFieldKey = GlobalKey();

  late final AnimationController _layoutController;
  late final Animation<double> _layoutAnimation;

  Timer? _debounce;
  int _searchToken = 0;
  bool _searching = false;
  String? _error;
  List<CatalogLinkTarget> _results = const [];

  /// True while the search field should keep keyboard focus across layout moves.
  bool _retainSearchFocus = false;

  @override
  void initState() {
    super.initState();
    _layoutController = AnimationController(
      vsync: this,
      duration: _layoutDuration,
    );
    _layoutAnimation = CurvedAnimation(
      parent: _layoutController,
      curve: Curves.easeInOutCubic,
      reverseCurve: Curves.easeInOutCubic,
    );
    _layoutController.addListener(_preserveSearchFocus);
    _searchController.addListener(_onQueryChanged);
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _layoutController.removeListener(_preserveSearchFocus);
    _layoutController.dispose();
    _searchController.removeListener(_onQueryChanged);
    _searchController.dispose();
    _focusNode.removeListener(_onFocusChanged);
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    if (_focusNode.hasFocus) {
      _retainSearchFocus = true;
    } else if (_searchController.text.trim().isEmpty) {
      _retainSearchFocus = false;
    }
  }

  void _preserveSearchFocus() {
    if (!_retainSearchFocus || !mounted) return;
    if (!_focusNode.hasFocus && _focusNode.canRequestFocus) {
      _focusNode.requestFocus();
    }
  }

  void _onQueryChanged() {
    setState(() {});
    final query = _searchController.text.trim();
    final wantsResults = query.isNotEmpty;

    if (wantsResults) {
      _retainSearchFocus = true;
      if (!_layoutController.isCompleted) {
        _layoutController.forward().whenComplete(_preserveSearchFocus);
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _preserveSearchFocus();
      });
    } else if (!_layoutController.isDismissed) {
      _layoutController.reverse();
    }

    _debounce?.cancel();
    if (!wantsResults) {
      setState(() {
        _results = const [];
        _error = null;
        _searching = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 280), () {
      _runSearch(query);
    });
  }

  Future<void> _runSearch(String query) async {
    final tokenId = ++_searchToken;
    setState(() {
      _searching = true;
      _error = null;
    });
    try {
      final accessToken = await widget.auth.requireAccessToken();
      if (accessToken == null) {
        throw AuthApiException('Not authenticated');
      }
      final results = await _api.search(accessToken, query: query, limit: 40);
      if (!mounted || tokenId != _searchToken) return;
      setState(() {
        _results = results;
        _searching = false;
      });
    } on AuthApiException catch (e) {
      if (!mounted || tokenId != _searchToken) return;
      setState(() {
        _error = e.message;
        _results = const [];
        _searching = false;
      });
    } catch (_) {
      if (!mounted || tokenId != _searchToken) return;
      setState(() {
        _error = 'Could not search catalog';
        _results = const [];
        _searching = false;
      });
    }
  }

  Future<void> _openHit(CatalogLinkTarget hit) async {
    _retainSearchFocus = false;
    await openCatalogRecordDetail(
      context: context,
      auth: widget.auth,
      kindApiValue: hit.kind,
      itemId: hit.id,
    );
  }

  Widget _buildSearchField(ColorScheme scheme) {
    final hasQuery = _searchController.text.trim().isNotEmpty;

    return Material(
      elevation: 2.5,
      shadowColor: Colors.black.withValues(alpha: 0.16),
      borderRadius: BorderRadius.circular(28),
      color: scheme.surface,
      child: TextField(
        key: _searchFieldKey,
        controller: _searchController,
        focusNode: _focusNode,
        decoration: InputDecoration(
          hintText: 'Search spells, items, classes…',
          hintStyle: TextStyle(color: scheme.onSurfaceVariant),
          prefixIcon: Icon(Icons.search, color: scheme.onSurfaceVariant),
          suffixIcon: hasQuery
              ? IconButton(
                  tooltip: 'Clear',
                  icon: Icon(Icons.close, color: scheme.onSurfaceVariant),
                  onPressed: () {
                    _retainSearchFocus = true;
                    _searchController.clear();
                    _focusNode.requestFocus();
                  },
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(28),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(28),
            borderSide: BorderSide(
              color: scheme.outlineVariant.withValues(alpha: 0.55),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(28),
            borderSide: BorderSide(color: scheme.primary, width: 1.5),
          ),
          filled: true,
          fillColor: scheme.surface,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 14,
          ),
        ),
        textInputAction: TextInputAction.search,
        onSubmitted: (value) {
          final q = value.trim();
          if (q.isNotEmpty) _runSearch(q);
          _focusNode.requestFocus();
        },
      ),
    );
  }

  Widget _buildResultsBody(BuildContext context, String query) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => _runSearch(query),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (!_searching && _results.isEmpty) {
      return Center(
        child: Text(
          'No records match “$query”.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      itemCount: _results.length,
      separatorBuilder: (_, _) => const SizedBox(height: 4),
      itemBuilder: (context, index) {
        final hit = _results[index];
        final kind = CatalogKind.tryParseApiValue(hit.kind);
        final icon = kind?.pageIcon ?? Icons.article_outlined;
        final typeLabel = kind?.displayLabel ?? hit.kind;
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _searchMaxWidth),
            child: ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              leading: Icon(icon, color: scheme.primary),
              title: Text(
                hit.name,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: scheme.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              subtitle: Text(typeLabel),
              onTap: () => _openHit(hit),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final user = widget.auth.user;
    final role = user?.isDm == true ? 'Dungeon Master' : 'Player';
    final query = _searchController.text.trim();

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            scheme.surface,
            Color.alphaBlend(
              scheme.primary.withValues(alpha: 0.04),
              scheme.surface,
            ),
          ],
        ),
      ),
      child: AnimatedBuilder(
        animation: _layoutAnimation,
        builder: (context, child) {
          final t = _layoutAnimation.value;
          final brandSize = _lerp(64, 28, t);
          final roleOpacity = (1.0 - t).clamp(0.0, 1.0);
          final hintOpacity = (1.0 - t * 1.35).clamp(0.0, 1.0);
          final resultsOpacity = Curves.easeOut.transform(
            ((t - 0.28) / 0.72).clamp(0.0, 1.0),
          );
          final resultsSlide = _lerp(24, 0, resultsOpacity);

          // Approximate hero block height so we can center it when idle.
          final heroHeight = brandSize +
              (roleOpacity > 0.05 ? 10 + 20 : 0) +
              _lerp(36, 16, t) +
              56 +
              (hintOpacity > 0.05 ? _lerp(18, 0, t) + 20 : 0);

          return LayoutBuilder(
            builder: (context, constraints) {
              final maxH = constraints.maxHeight;
              final idleTop = ((maxH - heroHeight) / 2).clamp(24.0, maxH);
              final searchingTop = 12.0;
              final heroTop = _lerp(idleTop, searchingTop, t);
              final resultsTop = heroTop + heroHeight + _lerp(8, 4, t);

              return Stack(
                children: [
                  Positioned(
                    top: heroTop,
                    left: 0,
                    right: 0,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'RPG Manager',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.displayMedium?.copyWith(
                              fontSize: brandSize,
                              fontWeight: FontWeight.w600,
                              letterSpacing: brandSize > 40 ? -1.0 : -0.3,
                              height: 1.05,
                              color: scheme.onSurface,
                            ),
                          ),
                          if (roleOpacity > 0.01)
                            Opacity(
                              opacity: roleOpacity,
                              child: Padding(
                                padding: const EdgeInsets.only(top: 10),
                                child: Text(
                                  role,
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                    letterSpacing: 0.4,
                                  ),
                                ),
                              ),
                            ),
                          SizedBox(height: _lerp(36, 16, t)),
                          child!,
                          if (hintOpacity > 0.01)
                            Opacity(
                              opacity: hintOpacity,
                              child: Padding(
                                padding: EdgeInsets.only(top: _lerp(18, 0, t)),
                                child: Text(
                                  'Search any catalog record',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  if (t > 0.05)
                    Positioned(
                      top: resultsTop,
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Opacity(
                        opacity: resultsOpacity,
                        child: Transform.translate(
                          offset: Offset(0, resultsSlide),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (_searching)
                                const LinearProgressIndicator(minHeight: 2)
                              else
                                const SizedBox(height: 2),
                              Expanded(
                                child: _buildResultsBody(context, query),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          );
        },
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _searchMaxWidth),
          child: _buildSearchField(scheme),
        ),
      ),
    );
  }
}

double _lerp(double a, double b, double t) => a + (b - a) * t;
