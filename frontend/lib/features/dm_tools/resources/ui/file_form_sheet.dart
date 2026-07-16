import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../data/local_resource_file_copy.dart';
import '../data/resource_models.dart';

class FileFormResult {
  const FileFormResult({
    required this.name,
    required this.authorId,
    this.source,
    this.pickedPath,
  });

  final String name;
  final int authorId;
  final String? source;
  final String? pickedPath;
}

Future<FileFormResult?> showFileFormSheet(
  BuildContext context, {
  required List<Author> authors,
}) {
  return showModalBottomSheet<FileFormResult>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => _FileFormSheet(authors: authors),
  );
}

class _FileFormSheet extends StatefulWidget {
  const _FileFormSheet({required this.authors});

  final List<Author> authors;

  @override
  State<_FileFormSheet> createState() => _FileFormSheetState();
}

class _FileFormSheetState extends State<_FileFormSheet> {
  final _nameController = TextEditingController();
  final _sourceController = TextEditingController();
  late int _authorId = widget.authors.first.id;
  String? _pickedPath;
  String? _pickedName;

  @override
  void dispose() {
    _nameController.dispose();
    _sourceController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      withData: false,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.single;
    setState(() {
      _pickedPath = file.path;
      _pickedName = file.name;
      if (_nameController.text.trim().isEmpty && file.name.isNotEmpty) {
        _nameController.text = file.name;
      }
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
    if (isDesktopFileStorageSupported &&
        (_pickedPath == null || _pickedPath!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choose a file to copy locally')),
      );
      return;
    }
    final source = _sourceController.text.trim();
    Navigator.pop(
      context,
      FileFormResult(
        name: name,
        authorId: _authorId,
        source: source.isEmpty ? null : source,
        pickedPath: _pickedPath,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final desktop = isDesktopFileStorageSupported;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 8, 20, 20 + bottom),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'New file',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              initialValue: _authorId,
              decoration: const InputDecoration(
                labelText: 'Author',
                border: OutlineInputBorder(),
              ),
              items: [
                for (final author in widget.authors)
                  DropdownMenuItem(
                    value: author.id,
                    child: Text(author.name),
                  ),
              ],
              onChanged: (value) {
                if (value == null) return;
                setState(() => _authorId = value);
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _sourceController,
              decoration: const InputDecoration(
                labelText: 'Source',
                hintText: 'Optional URL',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 12),
            if (desktop) ...[
              OutlinedButton.icon(
                onPressed: _pickFile,
                icon: const Icon(Icons.attach_file),
                label: Text(_pickedName ?? 'Choose file'),
              ),
            ] else
              Text(
                'File picker is desktop only. You can still save metadata '
                'and a source URL.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _submit,
              child: const Text('Create file'),
            ),
          ],
        ),
      ),
    );
  }
}
