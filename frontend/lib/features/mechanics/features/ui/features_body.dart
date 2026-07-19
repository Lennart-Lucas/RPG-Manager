import 'package:flutter/material.dart';

import '../../../auth/data/auth_api.dart';
import '../../../auth/state/auth_controller.dart';
import '../../../catalog/data/catalog_api.dart';
import '../../../catalog/data/catalog_kind.dart';
import '../../../catalog/data/catalog_models.dart';
import '../../mechanics_icons.dart';
import '../data/feature_model.dart';
import 'feature_detail_page.dart';
import 'feature_form_sheet.dart';

class FeaturesBody extends StatefulWidget {
  const FeaturesBody({super.key, required this.auth});

  final AuthController auth;

  @override
  State<FeaturesBody> createState() => _FeaturesBodyState();
}

class _FeaturesBodyState extends State<FeaturesBody> {
  final _api = CatalogApi();

  bool _loading = true;
  String? _error;
  List<CatalogItem> _items = const [];

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<String?> _token() => widget.auth.requireAccessToken();

  MonsterFeature _featureFromItem(CatalogItem item) {
    return MonsterFeature.fromCatalogPayload(
      name: item.name,
      payload: item.payload,
    );
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final token = await _token();
      if (token == null) {
        throw AuthApiException('Not authenticated');
      }
      final items = await _api.list(token, CatalogKind.features);
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } on AuthApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load features';
        _loading = false;
      });
    }
  }

  Future<void> _create() async {
    try {
      if (!mounted) return;
      final feature = await showFeatureFormSheet(context, auth: widget.auth);
      if (feature == null || !mounted) return;
      final token = await _token();
      if (token == null) return;
      await _api.create(
        accessToken: token,
        kind: CatalogKind.features,
        name: feature.name,
        payload: feature.toJson(),
      );
      await _reload();
    } on AuthApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not create feature')),
      );
    }
  }

  Future<void> _edit(CatalogItem item) async {
    try {
      if (!mounted) return;
      final existing = _featureFromItem(item);
      final feature = await showFeatureFormSheet(
        context,
        initial: existing,
        auth: widget.auth,
      );
      if (feature == null || !mounted) return;
      final token = await _token();
      if (token == null) return;
      await _api.update(
        accessToken: token,
        kind: CatalogKind.features,
        itemId: item.id,
        name: feature.name,
        payload: feature.toJson(),
      );
      await _reload();
    } on AuthApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not update feature')),
      );
    }
  }

  Future<void> _openDetail(CatalogItem item) async {
    final feature = _featureFromItem(item);
    final deleted = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => FeatureDetailPage(
          auth: widget.auth,
          item: item,
          feature: feature.copyWith(name: item.name),
        ),
      ),
    );
    if (deleted == true && mounted) {
      await _reload();
    }
  }

  String _subtitle(MonsterFeature feature) {
    final parts = <String>[
      feature.category.label,
      feature.rarity.label,
      '${feature.effectPoints} EP',
    ];
    if (feature.activationTime != FeatureActivation.none) {
      parts.add(feature.activationTime.label);
    }
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Stack(
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: Center(
              child: Opacity(
                opacity: 0.08,
                child: Icon(
                  featuresPageIcon,
                  size: 440,
                  color: scheme.onSurface,
                ),
              ),
            ),
          ),
        ),
        if (_loading)
          const Center(child: CircularProgressIndicator())
        else if (_error != null)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_error!, textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _reload,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          )
        else if (_items.isEmpty)
          RefreshIndicator(
            onRefresh: _reload,
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 24, 24, 100),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'No features yet',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Tap + to add your first feature.',
                              textAlign: TextAlign.center,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          )
        else
          RefreshIndicator(
            onRefresh: _reload,
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              itemCount: _items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final item = _items[index];
                final feature = _featureFromItem(item);
                return Material(
                  color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(12),
                  child: ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    leading: Icon(featuresPageIcon, color: scheme.primary),
                    title: Text(item.name),
                    subtitle: Text(_subtitle(feature)),
                    onTap: () => _openDetail(item),
                    onLongPress: () => _edit(item),
                  ),
                );
              },
            ),
          ),
        Positioned(
          right: 20,
          bottom: 20,
          child: FloatingActionButton(
            onPressed: _create,
            backgroundColor: scheme.primary,
            foregroundColor: scheme.onPrimary,
            child: const Icon(Icons.add),
          ),
        ),
      ],
    );
  }
}
