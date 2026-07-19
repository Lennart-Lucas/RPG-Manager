import 'package:flutter/material.dart';

import '../../auth/data/auth_api.dart';
import '../../auth/state/auth_controller.dart';
import '../../player_options/skills/data/default_skills.dart';
import '../../player_options/skills/data/skill_model.dart';
import '../../player_options/skills/ui/skill_form_sheet.dart';
import '../data/catalog_api.dart';
import '../data/catalog_kind.dart';
import '../data/catalog_models.dart';
import 'name_record_form_sheet.dart';
import 'open_catalog_detail.dart';


class CatalogBody extends StatefulWidget {
  const CatalogBody({
    super.key,
    required this.auth,
    required this.kind,
    required this.icon,
  });

  final AuthController auth;
  final CatalogKind kind;
  final IconData icon;

  @override
  State<CatalogBody> createState() => _CatalogBodyState();
}

class _CatalogBodyState extends State<CatalogBody> {
  final _api = CatalogApi();

  bool _loading = true;
  String? _error;
  List<CatalogItem> _items = const [];

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void didUpdateWidget(covariant CatalogBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.kind != widget.kind) {
      _reload();
    }
  }

  Future<String?> _token() => widget.auth.requireAccessToken();

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
      final items = await _api.list(token, widget.kind);
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
        _error = 'Could not load ${widget.kind.pluralLabel}';
        _loading = false;
      });
    }
  }

  Future<void> _create() async {
    if (widget.kind == CatalogKind.skills) {
      final skill = await showSkillFormSheet(context);
      if (skill == null || !mounted) return;
      try {
        final token = await _token();
        if (token == null) return;
        await _api.create(
          accessToken: token,
          kind: CatalogKind.skills,
          name: skill.name,
          payload: skill.toJson(),
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
          const SnackBar(content: Text('Could not create skill')),
        );
      }
      return;
    }

    final name = await showNameRecordFormSheet(
      context,
      singularLabel: widget.kind.singularLabel,
    );
    if (name == null || !mounted) return;
    try {
      final token = await _token();
      if (token == null) return;
      await _api.create(
        accessToken: token,
        kind: widget.kind,
        name: name,
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
        SnackBar(
          content: Text('Could not create ${widget.kind.singularLabel}'),
        ),
      );
    }
  }

  Future<void> _edit(CatalogItem item) async {
    if (widget.kind == CatalogKind.skills && isDefaultSkillName(item.name)) {
      return;
    }
    if (widget.kind == CatalogKind.skills) {
      final skill = await showSkillFormSheet(
        context,
        initial: SkillRecord.fromCatalogPayload(
          name: item.name,
          payload: item.payload,
        ),
      );
      if (skill == null || !mounted) return;
      try {
        final token = await _token();
        if (token == null) return;
        await _api.update(
          accessToken: token,
          kind: CatalogKind.skills,
          itemId: item.id,
          name: skill.name,
          payload: skill.toJson(),
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
          const SnackBar(content: Text('Could not update skill')),
        );
      }
      return;
    }

    final name = await showNameRecordFormSheet(
      context,
      singularLabel: widget.kind.singularLabel,
      initialName: item.name,
    );
    if (name == null || !mounted) return;
    try {
      final token = await _token();
      if (token == null) return;
      await _api.update(
        accessToken: token,
        kind: widget.kind,
        itemId: item.id,
        name: name,
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
        SnackBar(
          content: Text('Could not update ${widget.kind.singularLabel}'),
        ),
      );
    }
  }

  Future<void> _delete(CatalogItem item) async {
    if (widget.kind == CatalogKind.skills && isDefaultSkillName(item.name)) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete ${widget.kind.singularLabel}?'),
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
        kind: widget.kind,
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
        SnackBar(
          content: Text('Could not delete ${widget.kind.singularLabel}'),
        ),
      );
    }
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
                  widget.icon,
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
                              'No ${widget.kind.pluralLabel} yet',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Tap + to add your first ${widget.kind.singularLabel}.',
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
                final subtitle = catalogRecordSubtitle(item);
                final isLockedDefault = widget.kind == CatalogKind.skills &&
                    isDefaultSkillName(item.name);
                return Material(
                  color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(12),
                  child: ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    leading: Icon(widget.icon, color: scheme.primary),
                    title: Text(item.name),
                    subtitle: subtitle == null ? null : Text(subtitle),
                    trailing: isLockedDefault
                        ? null
                        : IconButton(
                            tooltip: 'Delete',
                            onPressed: () => _delete(item),
                            icon: Icon(
                              Icons.delete_outline,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                    onTap: isLockedDefault ? null : () => _edit(item),
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
