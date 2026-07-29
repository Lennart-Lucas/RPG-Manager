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
  late List<CampaignSession> _sessions = [
    ...CampaignRecord.sortSessions([...?widget.initial?.sessions]),
  ];

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
        sessions: CampaignRecord.sortSessions(_sessions),
      ),
    );
  }

  Future<void> _editSession(int? index) async {
    final existing = index == null ? null : _sessions[index];
    var date = existing?.parsedDateTime ?? DateTime.now();
    final titleController = TextEditingController(text: existing?.title ?? '');
    final result = await showDialog<CampaignSession>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocal) {
            return AlertDialog(
              title: Text(index == null ? 'Add session' : 'Edit session'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Date & time'),
                    subtitle: Text(date.toLocal().toString()),
                    trailing: const Icon(Icons.calendar_today_outlined),
                    onTap: () async {
                      final d = await showDatePicker(
                        context: context,
                        initialDate: date,
                        firstDate: DateTime(1970),
                        lastDate: DateTime(2100),
                      );
                      if (d == null || !context.mounted) return;
                      final t = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.fromDateTime(date),
                      );
                      if (t == null) return;
                      setLocal(() {
                        date = DateTime(
                          d.year,
                          d.month,
                          d.day,
                          t.hour,
                          t.minute,
                        );
                      });
                    },
                  ),
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(labelText: 'Title'),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    Navigator.pop(
                      context,
                      CampaignSession(
                        dateTime: date.toUtc().toIso8601String(),
                        title: titleController.text.trim(),
                      ),
                    );
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
    titleController.dispose();
    if (result == null) return;
    setState(() {
      final next = [..._sessions];
      if (index == null) {
        next.add(result);
      } else {
        next[index] = result;
      }
      _sessions = CampaignRecord.sortSessions(next);
    });
  }

  @override
  Widget build(BuildContext context) {
    final campaignName = _nameController.text.trim().isEmpty
        ? 'Campaign'
        : _nameController.text.trim();
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
            onChanged: (_) => setState(() {}),
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
          const SizedBox(height: ResourceFormStyles.sectionSpacing),
          Text(
            'Sessions',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          for (var i = 0; i < _sessions.length; i++)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                CampaignSession.displayName(
                  campaignName: campaignName,
                  index1Based: i + 1,
                  title: _sessions[i].title,
                ),
              ),
              subtitle: Text(_sessions[i].dateTime),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () => _editSession(i),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () {
                      setState(() => _sessions = [..._sessions]..removeAt(i));
                    },
                  ),
                ],
              ),
            ),
          TextButton.icon(
            onPressed: () => _editSession(null),
            icon: const Icon(Icons.add),
            label: const Text('Add session'),
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
