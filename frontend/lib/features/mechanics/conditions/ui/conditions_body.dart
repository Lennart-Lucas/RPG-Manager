import 'package:flutter/material.dart';

import '../../../auth/state/auth_controller.dart';
import '../../../catalog/data/catalog_kind.dart';
import '../../../catalog/data/catalog_models.dart';
import '../../mechanics_icons.dart';
import '../../ui/styled_mechanics_ui.dart';

class ConditionsBody extends StatelessWidget {
  const ConditionsBody({super.key, required this.auth});

  final AuthController auth;

  @override
  Widget build(BuildContext context) {
    return StyledMechanicsBody(
      auth: auth,
      kind: CatalogKind.conditions,
      singularLabel: 'condition',
      pluralLabel: 'conditions',
      fallbackIcon: conditionsPageIcon,
      defaultIconKey: 'monitor_heart',
      openDetail: (context, item) => Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (context) => ConditionDetailPage(auth: auth, item: item),
        ),
      ),
    );
  }
}

class ConditionDetailPage extends StatelessWidget {
  const ConditionDetailPage({
    super.key,
    required this.auth,
    required this.item,
  });

  final AuthController auth;
  final CatalogItem item;

  @override
  Widget build(BuildContext context) {
    return StyledMechanicsDetailPage(
      auth: auth,
      item: item,
      kind: CatalogKind.conditions,
      singularLabel: 'Condition',
      fallbackIcon: conditionsPageIcon,
      defaultIconKey: 'monitor_heart',
    );
  }
}
