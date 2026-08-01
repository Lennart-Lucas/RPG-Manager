import 'package:flutter/material.dart';

import '../../../../core/ui/record_list_card.dart';
import '../../../auth/data/auth_api.dart';
import '../../../auth/state/auth_controller.dart';
import '../../../catalog/data/catalog_api.dart';
import '../../../catalog/data/catalog_auto_link.dart';
import '../../../catalog/data/catalog_kind.dart';
import '../../../catalog/data/catalog_models.dart';
import '../../player_options_icons.dart';
import '../data/class_model.dart';
import '../data/subclass_model.dart';
import 'class_detail_page.dart';
import 'class_form_sheet.dart';

class ClassesBody extends StatefulWidget {
  const ClassesBody({super.key, required this.auth});

  final AuthController auth;

  @override
  State<ClassesBody> createState() => _ClassesBodyState();
}

class _ClassesBodyState extends State<ClassesBody> {
  final _api = CatalogApi();

  bool _loading = true;
  String? _error;
  List<CatalogItem> _items = const [];
  List<CatalogItem> _subclasses = const [];
  List<String> _skillNames = const [];

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<String?> _token() => widget.auth.requireAccessToken();

  ClassRecord _recordFromItem(CatalogItem item) {
    return ClassRecord.fromCatalogPayload(
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
      final results = await Future.wait([
        _api.list(token, CatalogKind.classes),
        _api.list(token, CatalogKind.skills),
        _api.list(token, CatalogKind.subclasses),
      ]);
      var classes = results[0];
      final subclasses = List<CatalogItem>.from(results[2]);
      classes = await _migrateLegacySubclasses(token, classes, subclasses);
      if (!mounted) return;
      setState(() {
        _items = classes;
        _skillNames = [for (final s in results[1]) s.name]..sort();
        _subclasses = subclasses;
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
        _error = 'Could not load classes';
        _loading = false;
      });
    }
  }

  Future<List<CatalogItem>> _migrateLegacySubclasses(
    String token,
    List<CatalogItem> classes,
    List<CatalogItem> subclassesOut,
  ) async {
    final updated = <CatalogItem>[];
    for (final item in classes) {
      final record = _recordFromItem(item);
      if (record.legacySubclasses.isEmpty) {
        updated.add(item);
        continue;
      }
      for (final legacy in record.legacySubclasses) {
        if (legacy.name.trim().isEmpty) continue;
        final created = await _api.create(
          accessToken: token,
          kind: CatalogKind.subclasses,
          name: legacy.name.trim(),
          payload: SubclassRecord(
            name: legacy.name.trim(),
            parentClassId: item.id,
            featuresByLevel: legacy.featuresByLevel,
          ).toJson(),
        );
        subclassesOut.add(created);
      }
      final cleaned = record.copyWith(legacySubclasses: const []);
      final next = await _api.update(
        accessToken: token,
        kind: CatalogKind.classes,
        itemId: item.id,
        name: cleaned.name,
        payload: cleaned.toJson(),
      );
      updated.add(next);
    }
    return updated;
  }

  int _subclassCountFor(int classId) {
    var count = 0;
    for (final item in _subclasses) {
      final record = SubclassRecord.fromCatalogPayload(
        name: item.name,
        payload: item.payload,
      );
      if (record.parentClassId == classId) count++;
    }
    return count;
  }

  Future<void> _create() async {
    try {
      final token = await _token();
      if (token == null || !mounted) return;
      final record = await showClassFormSheet(
        context,
        skillNames: _skillNames,
        searchLinks: (q) => searchCatalogLinkTargets(_api, token, q),
        loadAutoLinkTargets: () =>
            loadConditionDamageAutoLinkTargets(_api, token),
      );
      if (record == null || !mounted) return;
      await _api.create(
        accessToken: token,
        kind: CatalogKind.classes,
        name: record.name,
        payload: record.toJson(),
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
        const SnackBar(content: Text('Could not create class')),
      );
    }
  }

  Future<void> _open(CatalogItem item) async {
    final deleted = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => ClassDetailPage(auth: widget.auth, item: item),
      ),
    );
    if (deleted == true || mounted) await _reload();
  }

  Future<void> _delete(CatalogItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete class?'),
        content: Text('Delete “${item.name}”? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      final token = await _token();
      if (token == null) return;
      await _api.delete(
        accessToken: token,
        kind: CatalogKind.classes,
        itemId: item.id,
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
        const SnackBar(content: Text('Could not delete class')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Stack(
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: Center(
              child: Opacity(
                opacity: 0.08,
                child: Icon(
                  classesPageIcon,
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
                              'No classes yet',
                              textAlign: TextAlign.center,
                              style: textTheme.headlineSmall,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Tap + to add your first class.',
                              textAlign: TextAlign.center,
                              style: textTheme.bodyMedium?.copyWith(
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
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final item = _items[index];
                final record = _recordFromItem(item);
                final subclassCount = _subclassCountFor(item.id);
                final parts = <String>[
                  record.hitDie,
                  if (record.isCaster) 'Spellcaster' else 'Non-caster',
                  'Subclass at ${record.subclassChosenAtLevel}',
                  if (subclassCount > 0)
                    '$subclassCount subclass${subclassCount == 1 ? '' : 'es'}',
                ];
                return RecordListCard(
                  leading: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer.withValues(alpha: 0.88),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(
                      classesPageIcon,
                      size: 22,
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                  title: item.name,
                  subtitle: parts.join(' · '),
                  trailing: IconButton(
                    tooltip: 'Delete',
                    onPressed: () => _delete(item),
                    icon: Icon(
                      Icons.delete_outline,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  onTap: () => _open(item),
                  children: const [],
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
