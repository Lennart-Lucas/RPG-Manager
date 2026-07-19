import 'package:flutter/material.dart';

import '../../../auth/data/auth_api.dart';
import '../../../auth/state/auth_controller.dart';
import '../../../catalog/data/catalog_api.dart';
import '../../../catalog/data/catalog_kind.dart';
import '../../../catalog/data/catalog_models.dart';
import '../../mechanics_icons.dart';
import '../data/feature_ep.dart';
import '../data/feature_model.dart';
import 'feature_form_sheet.dart';

class FeatureDetailPage extends StatefulWidget {
  const FeatureDetailPage({
    super.key,
    required this.auth,
    required this.item,
    required this.feature,
  });

  final AuthController auth;
  final CatalogItem item;
  final MonsterFeature feature;

  @override
  State<FeatureDetailPage> createState() => _FeatureDetailPageState();
}

class _FeatureDetailPageState extends State<FeatureDetailPage> {
  final _api = CatalogApi();

  late CatalogItem _item = widget.item;
  late MonsterFeature _feature = widget.feature;

  Future<String?> _token() => widget.auth.requireAccessToken();

  MonsterFeature? _featureFromItem(CatalogItem item) {
    try {
      return MonsterFeature.fromCatalogPayload(
        name: item.name,
        payload: item.payload,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _edit() async {
    try {
      final updated = await showFeatureFormSheet(
        context,
        initial: _feature,
        auth: widget.auth,
      );
      if (updated == null || !mounted) return;
      final token = await _token();
      if (token == null) return;
      final item = await _api.update(
        accessToken: token,
        kind: CatalogKind.features,
        itemId: _item.id,
        name: updated.name,
        payload: updated.toJson(),
      );
      final parsed = _featureFromItem(item) ?? updated;
      if (!mounted) return;
      setState(() {
        _item = item;
        _feature = parsed.copyWith(name: item.name);
      });
    } on AuthApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not update feature')),
      );
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete feature?'),
        content: Text('Delete “${_item.name}”? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      final token = await _token();
      if (token == null) return;
      await _api.delete(
        accessToken: token,
        kind: CatalogKind.features,
        itemId: _item.id,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } on AuthApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not delete feature')),
      );
    }
  }

  String _effectSummary(FeatureEffect effect) {
    final cost = effect.cost > 0 ? effect.cost : computeEffectCost(effect);
    return '${effect.type.name} · ${effect.duration.name} · $cost EP';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final f = _feature;

    return Scaffold(
      appBar: AppBar(
        title: Text(_item.name),
        actions: [
          IconButton(
            tooltip: 'Edit',
            onPressed: _edit,
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            tooltip: 'Delete',
            onPressed: _delete,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            children: [
              Icon(featuresPageIcon, color: scheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  f.name,
                  style: textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _DetailRow(label: 'Category', value: f.category.label),
          _DetailRow(label: 'Rarity', value: f.rarity.label),
          _DetailRow(label: 'Delivery', value: f.delivery.label),
          _DetailRow(label: 'Effect points', value: '${f.effectPoints}'),
          _DetailRow(label: 'Activation', value: f.activationTime.label),
          if (f.hasRequirement)
            const _DetailRow(label: 'Requirement', value: 'Yes'),
          if (f.limitation.type != FeatureLimitationType.none)
            _DetailRow(
              label: 'Limitation',
              value: [
                f.limitation.type.name,
                if (f.limitation.value != null) f.limitation.value!,
                if (f.limitation.recoveryTrigger != null)
                  f.limitation.recoveryTrigger!,
              ].join(' · '),
            ),
          if (f.budgetSlot != null)
            _DetailRow(label: 'Budget slot', value: f.budgetSlot!.name),
          if (f.defence != null)
            _DetailRow(label: 'Defence', value: f.defence!.label),
          if (f.category != FeatureCategory.trait) ...[
            _DetailRow(
              label: f.range.mode.distanceLabel,
              value: [
                f.range.mode.label,
                if (f.range.feet != null) '${f.range.feet} ft.',
              ].join(' · '),
            ),
            _DetailRow(
              label: 'Targets',
              value: f.targets.quantity.name,
            ),
          ],
          if (f.deferral.isActive)
            _DetailRow(
              label: 'Deferral',
              value: '${f.deferral.type.name} (${f.deferral.turns ?? "?"})',
            ),
          if (f.effects.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'Effects',
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            for (final effect in f.effects)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text('• ${_effectSummary(effect)}'),
              ),
          ],
          const SizedBox(height: 16),
          Text(
            'Rules text',
            style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            f.text.isEmpty ? '(No text)' : f.text,
            style: textTheme.bodyLarge,
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: RichText(
        text: TextSpan(
          style: Theme.of(context).textTheme.bodyMedium,
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}
