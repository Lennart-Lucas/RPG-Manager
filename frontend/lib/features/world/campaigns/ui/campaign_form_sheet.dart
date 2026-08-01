import 'package:flutter/material.dart';

import '../../../../core/ui/markdown_form_field.dart';
import '../../../dm_tools/resources/ui/resource_form_helpers.dart';
import '../../ui/world_form_helpers.dart';
import '../data/campaign_model.dart';

Future<CampaignRecord?> showCampaignFormSheet(
  BuildContext context, {
  CampaignRecord? initial,
  required Map<int, String> characterNames,
  required Map<int, String> ruleNames,
  CatalogLinkSearch? searchLinks,
  CatalogAutoLinkLoader? loadAutoLinkTargets,
}) {
  final editing = initial != null;
  return showAdaptiveResourceForm<CampaignRecord>(
    context,
    title: editing ? 'Edit campaign' : 'New campaign',
    child: _CampaignForm(
      initial: initial,
      characterNames: characterNames,
      ruleNames: ruleNames,
      searchLinks: searchLinks,
      loadAutoLinkTargets: loadAutoLinkTargets,
    ),
  );
}

class _CampaignForm extends StatefulWidget {
  const _CampaignForm({
    this.initial,
    required this.characterNames,
    required this.ruleNames,
    this.searchLinks,
    this.loadAutoLinkTargets,
  });

  final CampaignRecord? initial;
  final Map<int, String> characterNames;
  final Map<int, String> ruleNames;
  final CatalogLinkSearch? searchLinks;
  final CatalogAutoLinkLoader? loadAutoLinkTargets;

  @override
  State<_CampaignForm> createState() => _CampaignFormState();
}

class _CampaignFormState extends State<_CampaignForm> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController =
      TextEditingController(text: widget.initial?.name ?? '');
  late final _descriptionController =
      TextEditingController(text: widget.initial?.description ?? '');
  late List<int> _playerIds = [...?widget.initial?.playerCharacterIds];
  late List<int> _ruleIds = [...?widget.initial?.houseRuleIds];

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _submit() {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;
    Navigator.pop(
      context,
      CampaignRecord(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        playerCharacterIds: _playerIds,
        houseRuleIds: _ruleIds,
        // Preserve unread legacy sessions until migration clears them.
        legacySessions: widget.initial?.legacySessions ?? const [],
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
          catalogMultiPickTile(
            context: context,
            label: 'Players',
            labels: catalogSelectionLabels(
              selected: _playerIds.toSet(),
              namesById: widget.characterNames,
            ),
            onTap: () => pickCatalogIds(
              context: context,
              title: 'Player characters',
              options: catalogPicklistOptions(widget.characterNames),
              selected: _playerIds.toSet(),
              onDone: (next) => setState(() => _playerIds = next.toList()),
            ),
          ),
          const SizedBox(height: ResourceFormStyles.fieldSpacing),
          catalogMultiPickTile(
            context: context,
            label: 'House rules',
            labels: catalogSelectionLabels(
              selected: _ruleIds.toSet(),
              namesById: widget.ruleNames,
            ),
            onTap: () => pickCatalogIds(
              context: context,
              title: 'House rules',
              options: catalogPicklistOptions(widget.ruleNames),
              selected: _ruleIds.toSet(),
              onDone: (next) => setState(() => _ruleIds = next.toList()),
            ),
          ),
          const SizedBox(height: ResourceFormStyles.fieldSpacing),
          MarkdownFormField(
            controller: _descriptionController,
            label: 'Description',
            minLines: 3,
            maxLines: 10,
            searchLinks: widget.searchLinks,
            loadAutoLinkTargets: widget.loadAutoLinkTargets,
          ),
          const SizedBox(height: ResourceFormStyles.fieldSpacing),
          Text(
            'Sessions are managed as their own records from the campaign page.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
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
