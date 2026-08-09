import 'package:flutter/material.dart';

import '../../../../core/ui/markdown_form_field.dart';
import '../../../catalog/data/catalog_models.dart';
import '../../../dm_tools/resources/ui/resource_form_helpers.dart';
import '../../ui/overview_sections.dart';
import '../../ui/overview_sections_editor.dart';
import '../data/session_model.dart';

Future<SessionRecord?> showSessionFormSheet(
  BuildContext context, {
  SessionRecord? initial,
  required List<CatalogItem> campaigns,
  int? preferredCampaignId,
  CatalogLinkSearch? searchLinks,
  CatalogAutoLinkLoader? loadAutoLinkTargets,
}) {
  final editing = initial != null;
  return showAdaptiveResourceForm<SessionRecord>(
    context,
    title: editing ? 'Edit session' : 'New session',
    child: _SessionForm(
      initial: initial,
      campaigns: campaigns,
      preferredCampaignId: preferredCampaignId,
      searchLinks: searchLinks,
      loadAutoLinkTargets: loadAutoLinkTargets,
    ),
  );
}

class _SessionForm extends StatefulWidget {
  const _SessionForm({
    this.initial,
    required this.campaigns,
    this.preferredCampaignId,
    this.searchLinks,
    this.loadAutoLinkTargets,
  });

  final SessionRecord? initial;
  final List<CatalogItem> campaigns;
  final int? preferredCampaignId;
  final CatalogLinkSearch? searchLinks;
  final CatalogAutoLinkLoader? loadAutoLinkTargets;

  @override
  State<_SessionForm> createState() => _SessionFormState();
}

class _SessionFormState extends State<_SessionForm> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController =
      TextEditingController(text: widget.initial?.name ?? '');
  late final _descriptionController =
      TextEditingController(text: widget.initial?.description ?? '');
  late int? _campaignId = widget.initial?.campaignId != null &&
          widget.initial!.campaignId > 0
      ? widget.initial!.campaignId
      : widget.preferredCampaignId;
  late DateTime _dateTime =
      widget.initial?.parsedDateTime?.toLocal() ?? DateTime.now();
  late List<OverviewSection> _overviewSections = [
    ...?widget.initial?.overviewSections,
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _dateTime,
      firstDate: DateTime(1970),
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_dateTime),
    );
    if (time == null || !mounted) return;
    setState(() {
      _dateTime = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  void _submit() {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;
    final campaignId = _campaignId;
    if (campaignId == null || campaignId <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a campaign')),
      );
      return;
    }
    Navigator.pop(
      context,
      SessionRecord(
        name: _nameController.text.trim(),
        campaignId: campaignId,
        dateTime: _dateTime.toUtc().toIso8601String(),
        description: _descriptionController.text.trim(),
        overviewSections: normalizeOverviewSections(_overviewSections),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final campaigns = [...widget.campaigns]
      ..sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );
    final localLabel = MaterialLocalizations.of(context);
    final dateLabel =
        '${localLabel.formatFullDate(_dateTime)} · ${localLabel.formatTimeOfDay(TimeOfDay.fromDateTime(_dateTime))}';

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
              label: 'Title',
            ),
            textCapitalization: TextCapitalization.sentences,
            autofocus: widget.initial == null,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Title is required';
              }
              return null;
            },
          ),
          const SizedBox(height: ResourceFormStyles.fieldSpacing),
          DropdownButtonFormField<int>(
            initialValue: campaigns.any((c) => c.id == _campaignId)
                ? _campaignId
                : null,
            decoration: ResourceFormStyles.inputDecoration(
              context,
              label: 'Campaign',
              helperText:
                  campaigns.isEmpty ? 'Create a campaign first' : null,
            ),
            items: [
              for (final campaign in campaigns)
                DropdownMenuItem(
                  value: campaign.id,
                  child: Text(campaign.name),
                ),
            ],
            onChanged: campaigns.isEmpty
                ? null
                : (value) => setState(() => _campaignId = value),
            validator: (value) {
              if (value == null) return 'Campaign is required';
              return null;
            },
          ),
          const SizedBox(height: ResourceFormStyles.fieldSpacing),
          InputDecorator(
            decoration: ResourceFormStyles.inputDecoration(
              context,
              label: 'Date & time',
            ),
            child: InkWell(
              onTap: _pickDateTime,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(child: Text(dateLabel)),
                    Icon(
                      Icons.calendar_today_outlined,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: ResourceFormStyles.fieldSpacing),
          OverviewSectionsEditor(
            sections: _overviewSections,
            onChanged: (next) => setState(() => _overviewSections = next),
            searchLinks: widget.searchLinks,
            loadAutoLinkTargets: widget.loadAutoLinkTargets,
          ),
          const SizedBox(height: ResourceFormStyles.fieldSpacing),
          MarkdownFormField(
            controller: _descriptionController,
            label: 'Notes',
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
