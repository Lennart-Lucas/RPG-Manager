import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/offline/offline_marker.dart';
import '../../../core/ui/markdown_form_field.dart';
import '../../../core/ui/record_list_card.dart';
import '../../auth/data/auth_api.dart';
import '../../auth/state/auth_controller.dart';
import '../../catalog/data/catalog_api.dart';
import '../../catalog/data/catalog_auto_link.dart';
import '../../catalog/data/catalog_kind.dart';
import '../../catalog/data/catalog_models.dart';
import '../../catalog/ui/catalog_appearance.dart';
import '../../catalog/ui/catalog_rich_text.dart';
import '../../dm_tools/resources/data/resource_models.dart';
import '../../dm_tools/resources/data/resources_api.dart';
import '../../dm_tools/resources/ui/resource_form_helpers.dart';
import '../data/styled_mechanics_record.dart';

Future<StyledMechanicsRecord?> showStyledMechanicsFormSheet(
  BuildContext context, {
  required String singularLabel,
  required IconData fallbackIcon,
  required String defaultIconKey,
  StyledMechanicsRecord? initial,
  List<ResourceFile> resourceFiles = const [],
  List<CatalogAppearanceIconEntry>? appearanceIcons,
  String appearancePickerTitle = 'Icon & color',
  CatalogLinkSearch? searchLinks,
  CatalogAutoLinkLoader? loadAutoLinkTargets,
}) {
  final editing = initial != null;
  return showAdaptiveResourceForm<StyledMechanicsRecord>(
    context,
    title: editing ? 'Edit $singularLabel' : 'New $singularLabel',
    child: _StyledMechanicsForm(
      singularLabel: singularLabel,
      fallbackIcon: fallbackIcon,
      defaultIconKey: defaultIconKey,
      initial: initial,
      resourceFiles: resourceFiles,
      appearanceIcons: appearanceIcons,
      appearancePickerTitle: appearancePickerTitle,
      searchLinks: searchLinks,
      loadAutoLinkTargets: loadAutoLinkTargets,
    ),
  );
}

class _StyledMechanicsForm extends StatefulWidget {
  const _StyledMechanicsForm({
    required this.singularLabel,
    required this.fallbackIcon,
    required this.defaultIconKey,
    this.initial,
    this.resourceFiles = const [],
    this.appearanceIcons,
    this.appearancePickerTitle = 'Icon & color',
    this.searchLinks,
    this.loadAutoLinkTargets,
  });

  final String singularLabel;
  final IconData fallbackIcon;
  final String defaultIconKey;
  final StyledMechanicsRecord? initial;
  final List<ResourceFile> resourceFiles;
  final List<CatalogAppearanceIconEntry>? appearanceIcons;
  final String appearancePickerTitle;
  final CatalogLinkSearch? searchLinks;
  final CatalogAutoLinkLoader? loadAutoLinkTargets;

  @override
  State<_StyledMechanicsForm> createState() => _StyledMechanicsFormState();
}

class _StyledMechanicsFormState extends State<_StyledMechanicsForm> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController =
      TextEditingController(text: widget.initial?.name ?? '');
  late final _descriptionController =
      TextEditingController(text: widget.initial?.description ?? '');
  late final _sourcePageController = TextEditingController(
    text: widget.initial?.sourcePage?.toString() ?? '',
  );
  late String _iconKey = widget.initial?.iconKey ?? widget.defaultIconKey;
  late int? _colorArgb = widget.initial?.colorArgb;
  late int? _sourceFileId = widget.initial?.sourceFileId;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _sourcePageController.dispose();
    super.dispose();
  }

  int? _parseInt(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    return int.tryParse(trimmed);
  }

  void _submit() {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;
    Navigator.pop(
      context,
      StyledMechanicsRecord(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        iconKey: _iconKey,
        colorArgb: _colorArgb,
        sourceFileId: _sourceFileId,
        sourcePage: _parseInt(_sourcePageController.text),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          TextFormField(
            controller: _nameController,
            decoration: ResourceFormStyles.inputDecoration(
              context,
              label: 'Name',
            ),
            textCapitalization: TextCapitalization.words,
            autofocus: true,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Name is required';
              }
              return null;
            },
          ),
          const SizedBox(height: ResourceFormStyles.fieldSpacing),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: Builder(
                  builder: (context) {
                    final sourceFiles = resourceFilesForSourcePicker(
                      widget.resourceFiles,
                      selectedId: _sourceFileId,
                    );
                    return DropdownButtonFormField<int?>(
                      initialValue: _sourceFileId,
                      decoration: ResourceFormStyles.inputDecoration(
                        context,
                        label: 'Source',
                        helperText: sourceFiles.isEmpty
                            ? 'No resource files available'
                            : null,
                      ),
                      items: [
                        const DropdownMenuItem<int?>(
                          value: null,
                          child: Text('None'),
                        ),
                        for (final file in sourceFiles)
                          DropdownMenuItem<int?>(
                            value: file.id,
                            child: Text(file.name),
                          ),
                      ],
                      onChanged: (value) =>
                          setState(() => _sourceFileId = value),
                    );
                  },
                ),
              ),
              const SizedBox(width: ResourceFormStyles.fieldSpacing),
              Expanded(
                child: TextFormField(
                  controller: _sourcePageController,
                  decoration: ResourceFormStyles.inputDecoration(
                    context,
                    label: 'Page',
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
              ),
            ],
          ),
          const SizedBox(height: ResourceFormStyles.fieldSpacing),
          CatalogIconColorFields(
            iconKey: _iconKey,
            colorArgb: _colorArgb,
            fallbackIcon: widget.fallbackIcon,
            icons: widget.appearanceIcons,
            pickerTitle: widget.appearancePickerTitle,
            onIconChanged: (key) => setState(() => _iconKey = key),
            onColorChanged: (argb) => setState(() => _colorArgb = argb),
          ),
          const SizedBox(height: ResourceFormStyles.fieldSpacing),
          MarkdownFormField(
            controller: _descriptionController,
            label: 'Description',
            minLines: 4,
            maxLines: 12,
            searchLinks: widget.searchLinks,
            loadAutoLinkTargets: widget.loadAutoLinkTargets,
          ),
          const SizedBox(height: ResourceFormStyles.sectionSpacing),
          FilledButton(
            onPressed: _submit,
            child: Text(widget.initial == null ? 'Create' : 'Save'),
          ),
        ],
      ),
    );
  }
}

class StyledMechanicsListItemCard extends StatelessWidget {
  const StyledMechanicsListItemCard({
    super.key,
    required this.record,
    required this.fallbackIcon,
    required this.kindLabel,
    required this.onTap,
    this.onDelete,
  });

  final StyledMechanicsRecord record;
  final IconData fallbackIcon;
  final String kindLabel;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final color = record.resolvedColor(fallback: scheme.primary);
    final icon = record.resolvedIcon(fallback: fallbackIcon);
    final preview = record.descriptionPreview;

    return RecordListCard(
      leading: Container(
        width: 42,
        height: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(13),
        ),
        child: catalogAppearanceIconWidget(icon, size: 22, color: color),
      ),
      title: record.name.trim().isEmpty ? kindLabel : record.name.trim(),
      subtitle: kindLabel,
      trailing: onDelete == null
          ? Icon(Icons.chevron_right, color: scheme.onSurfaceVariant)
          : IconButton(
              tooltip: 'Delete',
              onPressed: onDelete,
              icon: Icon(Icons.delete_outline, color: scheme.onSurfaceVariant),
            ),
      onTap: onTap,
      children: [
        if (preview.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            preview,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.35,
            ),
          ),
        ],
      ],
    );
  }
}

class StyledMechanicsDetailPage extends StatefulWidget {
  const StyledMechanicsDetailPage({
    super.key,
    required this.auth,
    required this.item,
    required this.kind,
    required this.singularLabel,
    required this.fallbackIcon,
    required this.defaultIconKey,
  });

  final AuthController auth;
  final CatalogItem item;
  final CatalogKind kind;
  final String singularLabel;
  final IconData fallbackIcon;
  final String defaultIconKey;

  @override
  State<StyledMechanicsDetailPage> createState() =>
      _StyledMechanicsDetailPageState();
}

class _StyledMechanicsDetailPageState extends State<StyledMechanicsDetailPage> {
  final _api = CatalogApi();
  final _resourcesApi = ResourcesApi();
  late CatalogItem _item = widget.item;
  List<ResourceFile> _resourceFiles = const [];
  String? _sourceFileName;

  Future<String?> _token() => widget.auth.requireAccessToken();

  StyledMechanicsRecord get _record => StyledMechanicsRecord.fromCatalogPayload(
        name: _item.name,
        payload: _item.payload,
        defaultIconKey: widget.defaultIconKey,
      );

  @override
  void initState() {
    super.initState();
    _loadResources();
  }

  Future<void> _loadResources() async {
    try {
      final token = await _token();
      if (token == null) return;
      final files = await _resourcesApi.listFiles(token);
      if (!mounted) return;
      String? sourceName;
      final sourceId = _record.sourceFileId;
      if (sourceId != null) {
        for (final f in files) {
          if (f.id == sourceId) {
            sourceName = f.name;
            break;
          }
        }
      }
      setState(() {
        _resourceFiles = files;
        _sourceFileName = sourceName;
      });
    } catch (_) {
      // Source label is optional; ignore load failures.
    }
  }

  Future<void> _edit() async {
    try {
      final token = await _token();
      if (token == null || !mounted) return;
      if (_resourceFiles.isEmpty) {
        try {
          _resourceFiles = await _resourcesApi.listFiles(token);
        } catch (_) {}
      }
      if (!mounted) return;
      final updatedRecord = await showStyledMechanicsFormSheet(
        context,
        singularLabel: widget.singularLabel,
        fallbackIcon: widget.fallbackIcon,
        defaultIconKey: widget.defaultIconKey,
        initial: _record,
        resourceFiles: _resourceFiles,
        searchLinks: (q) => searchCatalogLinkTargets(_api, token, q),
        loadAutoLinkTargets: () =>
            loadConditionDamageAutoLinkTargets(_api, token),
      );
      if (updatedRecord == null || !mounted) return;
      final updated = await _api.update(
        accessToken: token,
        kind: widget.kind,
        itemId: _item.id,
        name: updatedRecord.name,
        payload: updatedRecord.toJson(),
      );
      if (!mounted) return;
      setState(() => _item = updated);
      await _loadResources();
    } on AuthApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update ${widget.singularLabel}')),
      );
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete ${widget.singularLabel}?'),
        content: Text('Delete “${_item.name}”? This cannot be undone.'),
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
        itemId: _item.id,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on AuthApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not delete ${widget.singularLabel}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final record = _record;
    final color = record.resolvedColor(fallback: scheme.primary);
    final icon = record.resolvedIcon(fallback: widget.fallbackIcon);

    return Scaffold(
      appBar: AppBar(
        title: Text(_item.name.trim().isEmpty ? widget.singularLabel : _item.name),
        actions: [
          const OfflineAppBarMarker(),
          if (widget.auth.canMutateCatalog) ...[
            IconButton(
              tooltip: 'Edit',
              icon: const Icon(Icons.edit_outlined),
              onPressed: _edit,
            ),
            IconButton(
              tooltip: 'Delete',
              icon: const Icon(Icons.delete_outline),
              onPressed: _delete,
            ),
          ],
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: Center(
                child: Opacity(
                  opacity: 0.08,
                  child: catalogAppearanceIconWidget(
                    icon,
                    size: 440,
                    color: color,
                  ),
                ),
              ),
            ),
          ),
          ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: catalogAppearanceIconWidget(
                      icon,
                      color: color,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_item.name, style: textTheme.headlineSmall),
                        const SizedBox(height: 4),
                        Text(
                          widget.singularLabel,
                          style: textTheme.titleMedium?.copyWith(
                            color: color,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (record.description.trim().isNotEmpty) ...[
                const SizedBox(height: 24),
                Text('Description', style: textTheme.titleSmall),
                const SizedBox(height: 8),
                CatalogRichText(
                  auth: widget.auth,
                  content: record.description,
                ),
              ] else ...[
                const SizedBox(height: 24),
                Text(
                  'No description yet.',
                  style: textTheme.bodyLarge?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
              if (record.sourceFileId != null ||
                  record.sourcePage != null ||
                  (_sourceFileName?.isNotEmpty ?? false)) ...[
                const SizedBox(height: 24),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: scheme.outlineVariant),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Sources', style: textTheme.titleMedium),
                        const SizedBox(height: 8),
                        Text(
                          '${_sourceFileName ?? 'Resource ${record.sourceFileId}'}'
                          '${record.sourcePage != null ? ' · p. ${record.sourcePage}' : ''}',
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class StyledMechanicsBody extends StatefulWidget {
  const StyledMechanicsBody({
    super.key,
    required this.auth,
    required this.kind,
    required this.singularLabel,
    required this.pluralLabel,
    required this.fallbackIcon,
    required this.defaultIconKey,
    required this.openDetail,
  });

  final AuthController auth;
  final CatalogKind kind;
  final String singularLabel;
  final String pluralLabel;
  final IconData fallbackIcon;
  final String defaultIconKey;
  final Future<bool?> Function(BuildContext context, CatalogItem item) openDetail;

  @override
  State<StyledMechanicsBody> createState() => _StyledMechanicsBodyState();
}

class _StyledMechanicsBodyState extends State<StyledMechanicsBody> {
  final _api = CatalogApi();
  final _resourcesApi = ResourcesApi();
  bool _loading = true;
  String? _error;
  List<CatalogItem> _items = const [];
  List<ResourceFile> _resourceFiles = const [];

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<String?> _token() => widget.auth.requireAccessToken();

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final token = await _token();
      if (token == null) throw AuthApiException('Not authenticated');
      final items = await _api.list(token, widget.kind);
      List<ResourceFile> files = const [];
      try {
        files = await _resourcesApi.listFiles(token);
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _items = items;
        _resourceFiles = files;
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
        _error = 'Could not load ${widget.pluralLabel}';
        _loading = false;
      });
    }
  }

  Future<void> _create() async {
    try {
      final token = await _token();
      if (token == null || !mounted) return;
      final record = await showStyledMechanicsFormSheet(
        context,
        singularLabel: widget.singularLabel,
        fallbackIcon: widget.fallbackIcon,
        defaultIconKey: widget.defaultIconKey,
        resourceFiles: _resourceFiles,
        searchLinks: (q) => searchCatalogLinkTargets(_api, token, q),
        loadAutoLinkTargets: () =>
            loadConditionDamageAutoLinkTargets(_api, token),
      );
      if (record == null || !mounted) return;
      await _api.create(
        accessToken: token,
        kind: widget.kind,
        name: record.name,
        payload: record.toJson(),
      );
      await _reload();
    } on AuthApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not create ${widget.singularLabel}')),
      );
    }
  }

  Future<void> _open(CatalogItem item) async {
    final deleted = await widget.openDetail(context, item);
    if (deleted == true || mounted) await _reload();
  }

  Future<void> _delete(CatalogItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete ${widget.singularLabel}?'),
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not delete ${widget.singularLabel}')),
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
                  widget.fallbackIcon,
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
                  FilledButton(onPressed: _reload, child: const Text('Retry')),
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
                    constraints:
                        BoxConstraints(minHeight: constraints.maxHeight),
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 24, 24, 100),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'No ${widget.pluralLabel} yet',
                              style: Theme.of(context).textTheme.headlineSmall,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Tap + to add your first ${widget.singularLabel}.',
                              textAlign: TextAlign.center,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(color: scheme.onSurfaceVariant),
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
                final record = StyledMechanicsRecord.fromCatalogPayload(
                  name: item.name,
                  payload: item.payload,
                  defaultIconKey: widget.defaultIconKey,
                );
                return StyledMechanicsListItemCard(
                  record: record,
                  fallbackIcon: widget.fallbackIcon,
                  kindLabel: widget.singularLabel,
                  onTap: () => _open(item),
                  onDelete: widget.auth.canMutateCatalog
                      ? () => _delete(item)
                      : null,
                );
              },
            ),
          ),
        if (widget.auth.canMutateCatalog)
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
