import 'package:flutter/material.dart';

import '../../../../core/ui/markdown_form_field.dart';
import '../../../auth/data/auth_api.dart';
import '../../../auth/state/auth_controller.dart';
import '../../../catalog/data/catalog_models.dart';
import '../../../dm_tools/pdf_extract/data/anthropic_key_store.dart';
import '../../../dm_tools/pdf_extract/data/extract_api.dart';
import '../../../dm_tools/resources/ui/resource_form_helpers.dart';
import '../data/class_model.dart';
import '../data/subclass_model.dart';
import 'class_ai_process_pane.dart';
import 'class_features_editor.dart';

Future<SubclassRecord?> showSubclassFormSheet(
  BuildContext context, {
  required AuthController auth,
  SubclassRecord? initial,
  required List<CatalogItem> parentClasses,
  int? preferredParentClassId,
  CatalogLinkSearch? searchLinks,
  CatalogAutoLinkLoader? loadAutoLinkTargets,
}) {
  final editing = initial != null;
  return showAdaptiveResourceForm<SubclassRecord>(
    context,
    title: editing ? 'Edit subclass' : 'New subclass',
    child: _SubclassForm(
      auth: auth,
      initial: initial,
      parentClasses: parentClasses,
      preferredParentClassId: preferredParentClassId,
      searchLinks: searchLinks,
      loadAutoLinkTargets: loadAutoLinkTargets,
    ),
  );
}

class _SubclassForm extends StatefulWidget {
  const _SubclassForm({
    required this.auth,
    this.initial,
    required this.parentClasses,
    this.preferredParentClassId,
    this.searchLinks,
    this.loadAutoLinkTargets,
  });

  final AuthController auth;
  final SubclassRecord? initial;
  final List<CatalogItem> parentClasses;
  final int? preferredParentClassId;
  final CatalogLinkSearch? searchLinks;
  final CatalogAutoLinkLoader? loadAutoLinkTargets;

  @override
  State<_SubclassForm> createState() => _SubclassFormState();
}

class _SubclassFormState extends State<_SubclassForm>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _extractApi = ExtractApi();
  final _keyStore = AnthropicKeyStore();
  late final _nameController =
      TextEditingController(text: widget.initial?.name ?? '');
  late final _descriptionController =
      TextEditingController(text: widget.initial?.description ?? '');
  final _processController = TextEditingController();
  late int? _parentClassId = widget.initial?.parentClassId != null &&
          widget.initial!.parentClassId > 0
      ? widget.initial!.parentClassId
      : widget.preferredParentClassId;
  late List<ClassFeature> _features = flattenClassFeaturesByLevel(
    widget.initial?.featuresByLevel ?? const {},
    minLevel: _minFeatureLevelFor(_parentClassId),
  );

  TabController? _tabController;
  bool _processing = false;
  int _formEpoch = 0;

  bool get _showProcessTab => widget.auth.user?.aiIntegration == true;

  @override
  void initState() {
    super.initState();
    if (_showProcessTab) {
      _tabController = TabController(length: 2, vsync: this);
    }
  }

  int _minFeatureLevelFor(int? parentClassId) {
    if (parentClassId == null || parentClassId <= 0) return 1;
    for (final parent in widget.parentClasses) {
      if (parent.id != parentClassId) continue;
      return ClassRecord.fromCatalogPayload(
        name: parent.name,
        payload: parent.payload,
      ).subclassChosenAtLevel.clamp(1, 20);
    }
    return 1;
  }

  int get _minFeatureLevel => _minFeatureLevelFor(_parentClassId);

  void _setParentClassId(int? parentClassId) {
    final minLevel = _minFeatureLevelFor(parentClassId);
    setState(() {
      _parentClassId = parentClassId;
      _features = sortClassFeaturesByLevel([
        for (final f in _features)
          f.copyWith(level: f.level < minLevel ? minLevel : f.level),
      ]);
    });
  }

  Map<String, dynamic>? _parentDefinition() {
    final parentId = _parentClassId;
    if (parentId == null || parentId <= 0) return null;
    for (final parent in widget.parentClasses) {
      if (parent.id != parentId) continue;
      return ClassRecord.fromCatalogPayload(
        name: parent.name,
        payload: parent.payload,
      ).toJson();
    }
    return null;
  }

  SubclassRecord? _snapshotOrNull() {
    final parentId = _parentClassId;
    if (parentId == null || parentId <= 0) return null;
    return SubclassRecord(
      name: _nameController.text.trim(),
      parentClassId: parentId,
      description: _descriptionController.text.trim(),
      featuresByLevel: groupClassFeaturesByLevel(
        _features,
        minLevel: _minFeatureLevel,
      ),
    );
  }

  void _applyRecord(SubclassRecord record) {
    final minLevel = _minFeatureLevelFor(
      record.parentClassId > 0 ? record.parentClassId : _parentClassId,
    );
    _nameController.text = record.name;
    _descriptionController.text = record.description;
    setState(() {
      _formEpoch++;
      if (record.parentClassId > 0) {
        _parentClassId = record.parentClassId;
      }
      _features = flattenClassFeaturesByLevel(
        record.featuresByLevel,
        minLevel: minLevel,
      );
    });
  }

  Future<void> _process() async {
    final prompt = _processController.text.trim();
    if (prompt.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a prompt or paste source text')),
      );
      return;
    }
    final snapshot = _snapshotOrNull();
    if (snapshot == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a parent class first')),
      );
      return;
    }
    final apiKey = (await _keyStore.read())?.trim() ?? '';
    if (apiKey.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add your Anthropic API key in Preferences.'),
        ),
      );
      return;
    }
    setState(() => _processing = true);
    try {
      final token = await widget.auth.requireAccessToken();
      if (token == null) return;
      final payload = await _extractApi.processClass(
        accessToken: token,
        anthropicApiKey: apiKey,
        kind: 'subclasses',
        prompt: prompt,
        current: snapshot.toJson(),
        definition: _parentDefinition(),
      );
      if (!mounted) return;
      final applied = SubclassRecord.fromJson({
        ...payload,
        'parentClassId': payload['parentClassId'] ?? snapshot.parentClassId,
      });
      _applyRecord(applied);
      _tabController?.animateTo(0);
    } on AuthApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not process subclass')),
      );
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  @override
  void dispose() {
    _tabController?.dispose();
    _nameController.dispose();
    _descriptionController.dispose();
    _processController.dispose();
    super.dispose();
  }

  void _submit() {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;
    final record = _snapshotOrNull();
    if (record == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a parent class')),
      );
      return;
    }
    Navigator.pop(context, record);
  }

  Widget _buildEditFields(BuildContext context) {
    final parents = [...widget.parentClasses]
      ..sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );
    final minFeatureLevel = _minFeatureLevel;
    return Form(
      key: _formKey,
      child: Column(
        key: ValueKey('subclass-edit-$_formEpoch'),
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
            autofocus: widget.initial == null,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Name is required';
              }
              return null;
            },
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
          const SizedBox(height: ResourceFormStyles.fieldSpacing),
          DropdownButtonFormField<int>(
            initialValue: parents.any((p) => p.id == _parentClassId)
                ? _parentClassId
                : null,
            decoration: ResourceFormStyles.inputDecoration(
              context,
              label: 'Parent class',
              helperText: parents.isEmpty
                  ? 'Create a class first'
                  : 'Features start at subclass level $minFeatureLevel',
            ),
            items: [
              for (final parent in parents)
                DropdownMenuItem(
                  value: parent.id,
                  child: Text(parent.name),
                ),
            ],
            onChanged: parents.isEmpty ? null : _setParentClassId,
            validator: (value) {
              if (value == null) return 'Parent class is required';
              return null;
            },
          ),
          const SizedBox(height: ResourceFormStyles.sectionSpacing),
          ClassFeaturesEditor(
            title: 'Subclass features',
            features: _features,
            minLevel: minFeatureLevel,
            searchLinks: widget.searchLinks,
            loadAutoLinkTargets: widget.loadAutoLinkTargets,
            onChanged: (next) => setState(() => _features = next),
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

  @override
  Widget build(BuildContext context) {
    if (!_showProcessTab || _tabController == null) {
      return _buildEditFields(context);
    }
    return AnimatedBuilder(
      animation: _tabController!,
      builder: (context, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'Edit'),
                Tab(text: 'Process'),
              ],
            ),
            const SizedBox(height: ResourceFormStyles.fieldSpacing),
            if (_tabController!.index == 0)
              _buildEditFields(context)
            else
              ClassAiProcessPane(
                controller: _processController,
                processing: _processing,
                onProcess: _process,
              ),
          ],
        );
      },
    );
  }
}
