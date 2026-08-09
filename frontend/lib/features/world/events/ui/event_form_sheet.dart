import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/ui/markdown_form_field.dart';
import '../../../dm_tools/resources/ui/resource_form_helpers.dart';
import '../../ui/overview_sections.dart';
import '../../ui/overview_sections_editor.dart';
import '../data/event_model.dart';

Future<EventRecord?> showEventFormSheet(
  BuildContext context, {
  EventRecord? initial,
  CatalogLinkSearch? searchLinks,
  CatalogAutoLinkLoader? loadAutoLinkTargets,
}) {
  final editing = initial != null;
  return showAdaptiveResourceForm<EventRecord>(
    context,
    title: editing ? 'Edit event' : 'New event',
    child: _EventForm(
      initial: initial,
      searchLinks: searchLinks,
      loadAutoLinkTargets: loadAutoLinkTargets,
    ),
  );
}

class _EventForm extends StatefulWidget {
  const _EventForm({
    this.initial,
    this.searchLinks,
    this.loadAutoLinkTargets,
  });

  final EventRecord? initial;
  final CatalogLinkSearch? searchLinks;
  final CatalogAutoLinkLoader? loadAutoLinkTargets;

  @override
  State<_EventForm> createState() => _EventFormState();
}

class _EventFormState extends State<_EventForm> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController =
      TextEditingController(text: widget.initial?.name ?? '');
  late final _descriptionController =
      TextEditingController(text: widget.initial?.description ?? '');
  late final _yearStartController = TextEditingController(
    text: widget.initial?.yearStart?.toString() ?? '',
  );
  late final _yearEndController = TextEditingController(
    text: widget.initial?.yearEnd?.toString() ?? '',
  );
  late List<OverviewSection> _overviewSections = [
    ...?widget.initial?.overviewSections,
  ];
  String? _yearError;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _yearStartController.dispose();
    _yearEndController.dispose();
    super.dispose();
  }

  int? _parseOptionalYear(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return null;
    return int.tryParse(text);
  }

  void _submit() {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;

    final startRaw = _yearStartController.text.trim();
    final endRaw = _yearEndController.text.trim();
    if (startRaw.isNotEmpty && int.tryParse(startRaw) == null) {
      setState(() => _yearError = 'Start year must be a whole number');
      return;
    }
    if (endRaw.isNotEmpty && int.tryParse(endRaw) == null) {
      setState(() => _yearError = 'End year must be a whole number');
      return;
    }

    final record = EventRecord(
      name: _nameController.text.trim(),
      description: _descriptionController.text.trim(),
      yearStart: _parseOptionalYear(startRaw),
      yearEnd: _parseOptionalYear(endRaw),
      overviewSections: normalizeOverviewSections(_overviewSections),
    );
    final yearError = record.validateYears();
    if (yearError != null) {
      setState(() => _yearError = yearError);
      return;
    }
    Navigator.pop(context, record);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
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
          Text(
            'Year (AR)',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            'Optional. Start alone is a single year; both make a range.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextFormField(
                  controller: _yearStartController,
                  decoration: ResourceFormStyles.inputDecoration(
                    context,
                    label: 'Start',
                    hintText: 'e.g. 1247',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    signed: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'-?\d*')),
                  ],
                  onChanged: (_) {
                    if (_yearError != null) {
                      setState(() => _yearError = null);
                    }
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _yearEndController,
                  decoration: ResourceFormStyles.inputDecoration(
                    context,
                    label: 'End',
                    hintText: 'optional',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    signed: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'-?\d*')),
                  ],
                  onChanged: (_) {
                    if (_yearError != null) {
                      setState(() => _yearError = null);
                    }
                  },
                ),
              ),
            ],
          ),
          if (_yearError != null) ...[
            const SizedBox(height: 6),
            Text(
              _yearError!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.error,
                  ),
            ),
          ],
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
