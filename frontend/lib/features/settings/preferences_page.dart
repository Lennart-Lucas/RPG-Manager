import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';

import '../dm_tools/pdf_extract/data/anthropic_key_store.dart';
import '../../core/config/app_config.dart';
import '../../core/offline/offline_sync_controller.dart';
import '../../core/platform/client_platform.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_controller.dart';
import '../auth/state/auth_controller.dart';
import 'obsidian/data/obsidian_export_controller.dart';

/// Preferences content shown inside [AppShell] (no own AppBar/drawer).
class PreferencesBody extends StatefulWidget {
  const PreferencesBody({
    super.key,
    required this.auth,
    required this.themeController,
  });

  final AuthController auth;
  final ThemeController themeController;

  @override
  State<PreferencesBody> createState() => _PreferencesBodyState();
}

class _PreferencesBodyState extends State<PreferencesBody> {
  final _keyStore = AnthropicKeyStore();
  String? _maskedKey;
  bool _keyLoading = true;

  @override
  void initState() {
    super.initState();
    _reloadKeyPreview();
  }

  Future<void> _reloadKeyPreview() async {
    final masked = await _keyStore.maskedPreview();
    if (!mounted) return;
    setState(() {
      _maskedKey = masked;
      _keyLoading = false;
    });
  }

  Future<void> _editAnthropicKey() async {
    final controller = TextEditingController();
    final save = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            _maskedKey == null ? 'Add Anthropic API key' : 'Update Anthropic API key',
          ),
          content: TextField(
            controller: controller,
            obscureText: true,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'API key',
              hintText: 'sk-ant-…',
            ),
            inputFormatters: [
              FilteringTextInputFormatter.singleLineFormatter,
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
    if (save != true) return;
    await _keyStore.save(controller.text);
    controller.dispose();
    await _reloadKeyPreview();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Anthropic API key saved on this device')),
    );
  }

  Future<void> _clearAnthropicKey() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear API key?'),
        content: const Text(
          'Remove the Anthropic API key stored on this device?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await _keyStore.clear();
    await _reloadKeyPreview();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Anthropic API key cleared')),
    );
  }

  Future<void> _resyncOfflineChanges() async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      const SnackBar(content: Text('Recovering offline changes…')),
    );
    final message =
        await OfflineSyncController.instance.recoverTempCreatesAndSync();
    if (!mounted) return;
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _pickObsidianVault() async {
    final export = ObsidianExportController.instance;
    final path = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Choose Obsidian vault',
    );
    if (path == null || !mounted) return;
    final error = await export.setVaultPath(path);
    if (!mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error)),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Obsidian vault saved — export runs on this device'),
        ),
      );
    }
  }

  Future<void> _clearObsidianVault() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Obsidian vault?'),
        content: const Text(
          'Stop exporting to the vault on this device? '
          'Existing notes in the vault are not deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await ObsidianExportController.instance.setVaultPath(null);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Obsidian export disabled on this device')),
    );
  }

  String _formatExportTime(DateTime? at) {
    if (at == null) return 'Never';
    final local = at.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)} '
        '${two(local.hour)}:${two(local.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = detectClientPlatform() == ClientPlatform.desktop;
    return AnimatedBuilder(
      animation: Listenable.merge([
        widget.themeController,
        widget.auth,
        if (isDesktop) ObsidianExportController.instance,
      ]),
      builder: (context, _) {
        final scheme = Theme.of(context).colorScheme;
        final aiEnabled = widget.auth.user?.aiIntegration ?? false;
        final export = ObsidianExportController.instance;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Theme',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            ...AppThemeId.values.map((id) {
              final selected = widget.themeController.themeId == id;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Material(
                  color: selected
                      ? scheme.primaryContainer.withValues(alpha: 0.55)
                      : scheme.surfaceContainerHighest.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(12),
                  child: ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: selected ? scheme.primary : scheme.outlineVariant,
                      ),
                    ),
                    leading: Icon(
                      id == AppThemeId.warlock
                          ? Icons.nightlight_round
                          : Icons.wb_sunny_outlined,
                      color: selected ? scheme.primary : null,
                    ),
                    title: Text(id.label),
                    subtitle: Text(id.subtitle),
                    trailing: selected
                        ? Icon(Icons.check_circle, color: scheme.primary)
                        : const Icon(Icons.circle_outlined),
                    onTap: () => widget.themeController.setTheme(id),
                  ),
                ),
              );
            }),
            const Divider(height: 32),
            Text(
              'AI',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('AI integration'),
              subtitle: Text(
                aiEnabled
                    ? 'In-app PDF spell extraction uses your Anthropic API key. '
                        'The key stays on this device and is only sent with extract requests.'
                    : 'When off, spell forms offer copy/paste templates for external AI tools.',
              ),
              value: aiEnabled,
              onChanged: widget.auth.busy
                  ? null
                  : (value) async {
                      final ok = await widget.auth.setAiIntegration(value);
                      if (!context.mounted) return;
                      if (!ok) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              widget.auth.errorMessage ??
                                  'Could not update AI preference',
                            ),
                          ),
                        );
                      }
                    },
            ),
            if (aiEnabled) ...[
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.key_outlined),
                title: const Text('Anthropic API key'),
                subtitle: Text(
                  _keyLoading
                      ? 'Loading…'
                      : (_maskedKey ?? 'Not set — required for PDF extraction'),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_maskedKey != null)
                      IconButton(
                        tooltip: 'Clear key',
                        onPressed: _clearAnthropicKey,
                        icon: const Icon(Icons.delete_outline),
                      ),
                    IconButton(
                      tooltip: _maskedKey == null ? 'Add key' : 'Update key',
                      onPressed: _editAnthropicKey,
                      icon: Icon(
                        _maskedKey == null
                            ? Icons.add_circle_outline
                            : Icons.edit_outlined,
                      ),
                    ),
                  ],
                ),
                onTap: _editAnthropicKey,
              ),
            ],
            if (isDesktop) ...[
              const Divider(height: 32),
              Text(
                'Obsidian export',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Mirrors catalog notes into a local vault folder '
                '(RPG Manager/). One-way: the database always wins. '
                'Path is stored only on this device.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.folder_special_outlined),
                title: const Text('Vault folder'),
                subtitle: Text(
                  export.vaultPath ?? 'Not set',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (export.vaultPath != null)
                      IconButton(
                        tooltip: 'Clear',
                        onPressed: _clearObsidianVault,
                        icon: const Icon(Icons.delete_outline),
                      ),
                    IconButton(
                      tooltip: 'Choose folder',
                      onPressed: _pickObsidianVault,
                      icon: const Icon(Icons.folder_open),
                    ),
                  ],
                ),
                onTap: _pickObsidianVault,
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  export.isExporting
                      ? Icons.sync
                      : (export.lastError != null
                          ? Icons.error_outline
                          : Icons.check_circle_outline),
                  color: export.lastError != null ? scheme.error : null,
                ),
                title: Text(
                  export.isExporting
                      ? 'Exporting…'
                      : 'Last export: ${_formatExportTime(export.lastExportAt)}',
                ),
                subtitle: export.lastError != null
                    ? Text(
                        export.lastError!,
                        style: TextStyle(color: scheme.error),
                      )
                    : const Text(
                        'Updates automatically when catalog records change.',
                      ),
                trailing: FilledButton(
                  onPressed: export.hasValidVault && !export.isExporting
                      ? () => export.exportNow()
                      : null,
                  child: const Text('Export now'),
                ),
              ),
            ],
            const Divider(height: 32),
            Text(
              'Offline',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.sync),
              title: const Text('Resync offline changes'),
              subtitle: const Text(
                'Re-queue local creates that failed to sync, then drain the pending queue.',
              ),
              trailing: FilledButton(
                onPressed: _resyncOfflineChanges,
                child: const Text('Resync'),
              ),
            ),
            const Divider(height: 32),
            ListTile(
              leading: const Icon(Icons.cloud_outlined),
              title: const Text('API base URL'),
              subtitle: Text(AppConfig.apiBaseUrl),
            ),
            const Divider(),
            const ListTile(
              leading: Icon(Icons.info_outline),
              title: Text('App'),
              subtitle: Text('RPG Manager'),
            ),
          ],
        );
      },
    );
  }
}
