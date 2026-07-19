import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../data/local_resource_file_copy.dart';
import '../data/resource_models.dart';
import 'resource_form_helpers.dart';

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
  ResourceFile? initial,
  String? existingLocalPath,
}) {
  final editing = initial != null;
  return showAdaptiveResourceForm<FileFormResult>(
    context,
    title: editing ? 'Edit file' : 'New file',
    child: _FileFormSheet(
      authors: authors,
      initial: initial,
      existingLocalPath: existingLocalPath,
    ),
  );
}

class _FileFormSheet extends StatefulWidget {
  const _FileFormSheet({
    required this.authors,
    this.initial,
    this.existingLocalPath,
  });

  final List<Author> authors;
  final ResourceFile? initial;
  final String? existingLocalPath;

  @override
  State<_FileFormSheet> createState() => _FileFormSheetState();
}

class _FileFormSheetState extends State<_FileFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController = TextEditingController(
    text: widget.initial?.name ?? '',
  );
  late final _sourceController = TextEditingController(
    text: widget.initial?.source ?? '',
  );
  late int _authorId = widget.initial?.authorId ?? widget.authors.first.id;
  String? _pickedPath;
  String? _pickedName;
  bool _submitted = false;

  bool get _editing => widget.initial != null;
  bool get _hasExistingLocal =>
      widget.existingLocalPath != null &&
      widget.existingLocalPath!.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _sourceController.addListener(_refreshValidation);
    if (_hasExistingLocal) {
      _pickedName = p.basename(widget.existingLocalPath!);
    }
  }

  @override
  void dispose() {
    _sourceController.removeListener(_refreshValidation);
    _nameController.dispose();
    _sourceController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        withData: false,
        lockParentWindow: true,
      );
      if (!mounted) return;
      if (result == null || result.files.isEmpty) return;
      final file = result.files.single;
      final path = file.path;
      if (path == null || path.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not read the selected file path.'),
          ),
        );
        return;
      }
      setState(() {
        _pickedPath = path;
        _pickedName = file.name;
        if (_nameController.text.trim().isEmpty && file.name.isNotEmpty) {
          _nameController.text = file.name;
        }
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('File picker failed: $error')),
      );
    }
  }

  void _submit() {
    setState(() => _submitted = true);
    final form = _formKey.currentState;
    final needsNewFile = isDesktopFileStorageSupported &&
        !_editing &&
        (_pickedPath == null || _pickedPath!.isEmpty);
    final missingReplacement = isDesktopFileStorageSupported &&
        _editing &&
        !_hasExistingLocal &&
        (_pickedPath == null || _pickedPath!.isEmpty);
    if (form == null ||
        !form.validate() ||
        needsNewFile ||
        missingReplacement) {
      return;
    }
    Navigator.pop(
      context,
      FileFormResult(
        name: _nameController.text.trim(),
        authorId: _authorId,
        source: _normalizedSource,
        pickedPath: _pickedPath,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final desktop = isDesktopFileStorageSupported;
    final showMissingFile = _submitted &&
        desktop &&
        ((_editing && !_hasExistingLocal && _pickedPath == null) ||
            (!_editing && _pickedPath == null));

    return Form(
      key: _formKey,
      autovalidateMode: _submitted
          ? AutovalidateMode.onUserInteraction
          : AutovalidateMode.disabled,
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
            autofocus: true,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Name is required';
              }
              return null;
            },
          ),
          const SizedBox(height: ResourceFormStyles.fieldSpacing),
          DropdownButtonFormField<int>(
            initialValue: _authorId,
            decoration: ResourceFormStyles.inputDecoration(
              context,
              label: 'Author',
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
            validator: (value) => value == null ? 'Author is required' : null,
          ),
          const SizedBox(height: ResourceFormStyles.fieldSpacing),
          TextFormField(
            controller: _sourceController,
            decoration: ResourceFormStyles.inputDecoration(
              context,
              label: 'Source',
              hintText: 'Optional URL',
            ),
            keyboardType: TextInputType.url,
            validator: (value) => _validateOptionalUrl(value),
          ),
          const SizedBox(height: ResourceFormStyles.sectionSpacing),
          if (desktop) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Local file',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _editing
                        ? 'Optional: choose a new file to replace the local copy.'
                        : 'The file is copied into this app on this device only.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _pickFile,
                    icon: const Icon(Icons.attach_file),
                    label: Text(
                      _pickedName ??
                          (_editing ? 'Replace file' : 'Choose file'),
                    ),
                  ),
                  if (showMissingFile) ...[
                    const SizedBox(height: 8),
                    Text(
                      'A file is required on desktop.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.error,
                          ),
                    ),
                  ],
                ],
              ),
            ),
          ] else
            Text(
              'File picker is desktop only. You can still save metadata '
              'and a source URL.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          const SizedBox(height: ResourceFormStyles.sectionSpacing),
          FilledButton(
            onPressed: _submit,
            child: Text(_editing ? 'Save file' : 'Create file'),
          ),
        ],
      ),
    );
  }

  String? get _normalizedSource {
    final trimmed = _sourceController.text.trim();
    return trimmed.isEmpty ? null : trimmed;
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

  void _refreshValidation() {
    if (mounted && _submitted) {
      setState(() {});
    }
  }
}
