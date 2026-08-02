import 'package:random_table_engine/generation_engine.dart';

import '../../../auth/data/auth_api.dart';
import '../../../catalog/data/catalog_api.dart';
import '../../../catalog/data/catalog_kind.dart';
import '../../../catalog/data/catalog_models.dart';
import 'generator_record_mapping.dart';

class GeneratorApplyResult {
  const GeneratorApplyResult({
    required this.created,
  });

  final List<GeneratorAppliedItem> created;
}

class GeneratorAppliedItem {
  const GeneratorAppliedItem({
    required this.genId,
    required this.catalogId,
    required this.kind,
    required this.name,
  });

  final String genId;
  final int catalogId;
  final CatalogKind kind;
  final String name;
}

class GeneratorApplyException implements Exception {
  GeneratorApplyException(this.message, {this.partial = const []});

  final String message;
  final List<GeneratorAppliedItem> partial;

  @override
  String toString() => message;
}

/// Creates catalog items from generated records using [mapping].
class GeneratorApplyService {
  GeneratorApplyService({CatalogApi? api}) : _api = api ?? CatalogApi();

  final CatalogApi _api;

  Future<GeneratorApplyResult> apply({
    required String accessToken,
    required List<GeneratedRecord> records,
    required GeneratorRecordMapping mapping,
    int? rootParentCatalogId,
    String? processRecordType,
  }) async {
    if (!mapping.hasBindings) {
      throw GeneratorApplyException('Record mapping has no bindings');
    }
    final mappingError = mapping.validate();
    if (mappingError != null) {
      throw GeneratorApplyException(mappingError);
    }

    final ordered = recordsToApplyInOrder(
      records: records,
      mapping: mapping,
      processRecordType: processRecordType,
    );
    if (ordered.isEmpty) {
      throw GeneratorApplyException(
        'No generated records match the mapping bindings',
      );
    }

    final idMap = <String, int>{};
    final created = <GeneratorAppliedItem>[];

    for (final record in ordered) {
      late final GeneratorMappedCreate draft;
      try {
        draft = mapping.buildCreate(
          record: record,
          allRecords: records,
          catalogIdByGenId: idMap,
          rootParentCatalogId: rootParentCatalogId,
          processRecordType: processRecordType,
        );
      } on FormatException catch (e) {
        throw GeneratorApplyException(e.message, partial: created);
      }

      try {
        final item = await _api.create(
          accessToken: accessToken,
          kind: draft.kind,
          name: draft.name,
          payload: draft.payload,
        );
        idMap[record.id] = item.id;
        created.add(
          GeneratorAppliedItem(
            genId: record.id,
            catalogId: item.id,
            kind: draft.kind,
            name: item.name,
          ),
        );
      } on AuthApiException catch (e) {
        final suffix = created.isEmpty
            ? ''
            : ' (${created.length} created before failure)';
        throw GeneratorApplyException(
          'Failed creating ${draft.kind.singularLabel} “${draft.name}”: '
          '${e.message}$suffix',
          partial: created,
        );
      }
    }

    return GeneratorApplyResult(created: created);
  }

  Future<List<CatalogItem>> listForParentPicker({
    required String accessToken,
    required CatalogKind kind,
  }) {
    return _api.list(accessToken, kind);
  }
}
