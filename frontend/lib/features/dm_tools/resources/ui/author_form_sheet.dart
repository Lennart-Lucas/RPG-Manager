import 'package:flutter/material.dart';

import '../data/resource_models.dart';

class AuthorFormResult {
  const AuthorFormResult({required this.name, required this.links});

  final String name;
  final List<AuthorLink> links;
}

Future<AuthorFormResult?> showAuthorFormSheet(BuildContext context) {
  return showModalBottomSheet<AuthorFormResult>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => const _AuthorFormSheet(),
  );
}

class _AuthorFormSheet extends StatefulWidget {
  const _AuthorFormSheet();

  @override
  State<_AuthorFormSheet> createState() => _AuthorFormSheetState();
}

class _AuthorFormSheetState extends State<_AuthorFormSheet> {
  final _nameController = TextEditingController();
  final _links = <_LinkRow>[];

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
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name is required')),
      );
      return;
    }
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
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 8, 20, 20 + bottom),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'New author',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.next,
              autofocus: true,
            ),
            const SizedBox(height: 16),
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
            ...List.generate(_links.length, (index) {
              final row = _links[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 2,
                      child: DropdownButtonFormField<String>(
                        initialValue: row.source,
                        decoration: const InputDecoration(
                          labelText: 'Type',
                          border: OutlineInputBorder(),
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
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: row.urlController,
                        decoration: const InputDecoration(
                          labelText: 'URL',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    IconButton(
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
              child: const Text('Create author'),
            ),
          ],
        ),
      ),
    );
  }
}

class _LinkRow {
  _LinkRow() : urlController = TextEditingController();

  String source = 'website';
  final TextEditingController urlController;

  void dispose() => urlController.dispose();
}
