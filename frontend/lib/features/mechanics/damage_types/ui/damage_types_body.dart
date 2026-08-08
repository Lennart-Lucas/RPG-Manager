import 'package:flutter/material.dart';

import '../../../auth/state/auth_controller.dart';
import '../../../catalog/data/catalog_kind.dart';
import '../../../catalog/data/catalog_models.dart';
import '../../../catalog/ui/open_catalog_detail.dart';
import '../../mechanics_icons.dart';
import '../../ui/styled_mechanics_ui.dart';

class DamageTypesBody extends StatelessWidget {
  const DamageTypesBody({super.key, required this.auth});

  final AuthController auth;

  @override
  Widget build(BuildContext context) {
    return StyledMechanicsBody(
      auth: auth,
      kind: CatalogKind.damageTypes,
      singularLabel: 'damage type',
      pluralLabel: 'damage types',
      fallbackIcon: damageTypesPageIcon,
      defaultIconKey: 'local_fire_department',
      openDetail: (context, item) => openCatalogRecordDetail(
        context: context,
        auth: auth,
        kindApiValue: item.kind.apiValue,
        itemId: item.id,
      ),
    );
  }
}

class DamageTypeDetailPage extends StatelessWidget {
  const DamageTypeDetailPage({
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
      kind: CatalogKind.damageTypes,
      singularLabel: 'Damage type',
      fallbackIcon: damageTypesPageIcon,
      defaultIconKey: 'local_fire_department',
    );
  }
}
