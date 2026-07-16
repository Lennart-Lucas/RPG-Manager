import 'package:flutter/material.dart';

import '../data/resource_models.dart';
import 'resource_form_helpers.dart';

class AuthorFormResult {
  const AuthorFormResult({required this.name, required this.links});

  final String name;
  final List<AuthorLink> links;
}

Future<AuthorFormResult?> showAuthorFormSheet(
  BuildContext context, {
  Author? initial,
}) {
  final editing = initial != null;
  return showAdaptiveResourceForm<AuthorFormResult>(
    context,
    title: editing ? 'Edit author' : 'New author',
    child: _AuthorFormSheet(initial: initial),
  );
}

class _AuthorFormSheet extends StatefulWidget {
  const _AuthorFormSheet({this.initial});

  final Author? initial;

  @override
  State<_AuthorFormSheet> createState() => _AuthorFormSheetState();
}

class _AuthorFormSheetState extends State<_AuthorFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController = TextEditingController(
    text: widget.initial?.name ?? '',
  );
  late final _links = <_LinkRow>[
    for (final link in widget.initial?.links ?? const <AuthorLink>[])
      _LinkRow(source: link.source, url: link.url),
  ];

  bool get _editing => widget.initial != null;

  @override
  void dispose() {
    _nameController.dispose();
    for (final row in _links) {
      row.dispose();
    }
    super.dispose();
  }

  void _addLink() {
    setState(() {
      _links.add(_LinkRow());
    });
  }

  void _removeLink(int index) {
    setState(() {
      _links.removeAt(index).dispose();
    });
  }

  void _submit() {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }
    final name = _nameController.text.trim();
    final links = <AuthorLink>[];
    for (final row in _links) {
      final url = row.urlController.text.trim();
      if (url.isEmpty) continue;
      links.add(AuthorLink(source: row.source, url: url));
    }
    Navigator.pop(
      context,
      AuthorFormResult(name: name, links: links),
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
            textInputAction: TextInputAction.next,
            autofocus: true,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Name is required';
              }
              return null;
            },
          ),
          const SizedBox(height: ResourceFormStyles.sectionSpacing),
          Row(
            children: [
              Text(
                'Links',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: _addLink,
                icon: const Icon(Icons.add),
                label: const Text('Add'),
              ),
            ],
          ),
          const SizedBox(height: ResourceFormStyles.fieldSpacing),
          ...List.generate(_links.length, (index) {
            final row = _links[index];
            return Padding(
              padding: const EdgeInsets.only(
                bottom: ResourceFormStyles.fieldSpacing,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<String>(
                      initialValue: row.source,
                      decoration: ResourceFormStyles.inputDecoration(
                        context,
                        label: 'Type',
                      ),
                      items: [
                        for (final source in kLinkSources)
                          DropdownMenuItem(
                            value: source,
                            child: Text(source),
                          ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => row.source = value);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: row.urlController,
                      decoration: ResourceFormStyles.inputDecoration(
                        context,
                        label: 'URL',
                      ),
                      keyboardType: TextInputType.url,
                      validator: (value) => _validateOptionalUrl(value),
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    tooltip: 'Remove link',
                    onPressed: () => _removeLink(index),
                    icon: const Icon(Icons.remove_circle_outline),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _submit,
            child: Text(_editing ? 'Save author' : 'Create author'),
          ),
        ],
      ),
    );
  }

  String? _validateOptionalUrl(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return null;
    }
    final uri = Uri.tryParse(trimmed);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      return 'Enter a valid URL';
    }
    if (uri.scheme != 'http' && uri.scheme != 'https') {
      return 'URL must start with http or https';
    }
    return null;
  }
}

class _LinkRow {
  _LinkRow({String source = 'website', String url = ''})
      : source = source,
        urlController = TextEditingController(text: url);

  String source;
  final TextEditingController urlController;

  void dispose() => urlController.dispose();
}
