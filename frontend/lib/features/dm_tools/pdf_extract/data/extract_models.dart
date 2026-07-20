class ExtractSourceMeta {
  const ExtractSourceMeta({
    this.documentTitle,
    this.section,
    this.page,
  });

  final String? documentTitle;
  final String? section;
  final int? page;

  factory ExtractSourceMeta.fromJson(Map<String, dynamic> json) {
    return ExtractSourceMeta(
      documentTitle: json['document_title'] as String?,
      section: json['section'] as String?,
      page: json['page'] as int?,
    );
  }
}

class ExtractDraft {
  ExtractDraft({
    required this.kind,
    required this.payload,
    required this.sourceText,
    required this.boundaryConfidence,
    required this.duplicateNameInBatch,
    required this.duplicateNameInLibrary,
    this.libraryMatchId,
    this.libraryMatchName,
    required this.source,
    this.notes,
    this.unknownFields,
    required this.needsReview,
    required this.tier,
    this.rejected = false,
  });

  final String kind;
  Map<String, dynamic> payload;
  final String sourceText;
  final String boundaryConfidence;
  final bool duplicateNameInBatch;
  final bool duplicateNameInLibrary;
  final int? libraryMatchId;
  final String? libraryMatchName;
  final ExtractSourceMeta source;
  String? notes;
  Map<String, dynamic>? unknownFields;
  List<String> needsReview;
  final int tier;
  bool rejected;

  factory ExtractDraft.fromJson(Map<String, dynamic> json) {
    return ExtractDraft(
      kind: json['kind'] as String? ?? 'spells',
      payload: Map<String, dynamic>.from(
        (json['payload'] as Map?) ?? const {},
      ),
      sourceText: json['source_text'] as String? ?? '',
      boundaryConfidence:
          json['boundary_confidence'] as String? ?? 'deterministic',
      duplicateNameInBatch: json['duplicate_name_in_batch'] == true,
      duplicateNameInLibrary: json['duplicate_name_in_library'] == true,
      libraryMatchId: json['library_match_id'] as int?,
      libraryMatchName: json['library_match_name'] as String?,
      source: ExtractSourceMeta.fromJson(
        Map<String, dynamic>.from(
          (json['source'] as Map?) ?? const {},
        ),
      ),
      notes: json['notes'] as String?,
      unknownFields: json['unknown_fields'] is Map
          ? Map<String, dynamic>.from(json['unknown_fields'] as Map)
          : null,
      needsReview: [
        for (final item in (json['needs_review'] as List? ?? const []))
          if (item is String) item,
      ],
      tier: json['tier'] as int? ?? 1,
    );
  }

  int get riskScore {
    var score = 0;
    if (needsReview.contains('schema_validation_failed')) score += 100;
    if (needsReview.contains('boundary_unverified')) score += 80;
    if (needsReview.contains('claude_error')) score += 90;
    if (needsReview.contains('extraction_failed')) score += 85;
    if (needsReview.contains('not_a_spell')) score += 75;
    if (boundaryConfidence == 'unverified') score += 70;
    if (duplicateNameInLibrary) score += 40;
    if (duplicateNameInBatch) score += 30;

    // Soft Option-B flags only matter when core fields are incomplete.
    final softWeight = hasCompleteCoreFields ? 2 : 20;
    if (unknownFields != null && unknownFields!.isNotEmpty) {
      score += softWeight;
    }
    if (notes != null && notes!.trim().isNotEmpty) {
      score += hasCompleteCoreFields ? 1 : 10;
    }
    for (final reason in needsReview) {
      if (reason == 'unknown_fields' || reason == 'notes_present') {
        score += hasCompleteCoreFields ? 1 : 5;
      }
    }
    return score;
  }

  bool get hasCompleteCoreFields {
    final name = payload['name'];
    final hasName = name is String && name.trim().isNotEmpty;
    final description = payload['description'];
    final hasDescription =
        description is String && description.trim().isNotEmpty;
    return hasName &&
        payload['level'] != null &&
        payload['school'] != null &&
        hasDescription;
  }

  bool get isHardReviewIssue =>
      needsReview.contains('schema_validation_failed') ||
      needsReview.contains('boundary_unverified') ||
      needsReview.contains('claude_error') ||
      needsReview.contains('extraction_failed') ||
      needsReview.contains('not_a_spell') ||
      !hasCompleteCoreFields;

  bool get isNotASpell => needsReview.contains('not_a_spell');

  bool get isSoftReviewOnly =>
      !isHardReviewIssue &&
      needsReview.any(
        (r) =>
            r == 'unknown_fields' ||
            r == 'notes_present' ||
            r == 'duplicate_in_batch' ||
            r == 'duplicate_in_library',
      );

  bool get isCompleteClean =>
      hasCompleteCoreFields && !isHardReviewIssue && needsReview.isEmpty;

  String get displayName {
    final name = payload['name'];
    if (name is String && name.trim().isNotEmpty) return name.trim();
    return 'Untitled spell';
  }
}

class ExtractSectionSummary {
  const ExtractSectionSummary({
    this.title,
    required this.entryCount,
    required this.healthOk,
    required this.healthReasons,
    required this.tier,
    required this.leftoverChars,
  });

  final String? title;
  final int entryCount;
  final bool healthOk;
  final List<String> healthReasons;
  final int tier;
  final int leftoverChars;

  factory ExtractSectionSummary.fromJson(Map<String, dynamic> json) {
    return ExtractSectionSummary(
      title: json['title'] as String?,
      entryCount: json['entry_count'] as int? ?? 0,
      healthOk: json['health_ok'] == true,
      healthReasons: [
        for (final item in (json['health_reasons'] as List? ?? const []))
          if (item is String) item,
      ],
      tier: json['tier'] as int? ?? 1,
      leftoverChars: json['leftover_chars'] as int? ?? 0,
    );
  }
}

class ExtractJobResult {
  const ExtractJobResult({
    required this.drafts,
    required this.sectionSummaries,
  });

  final List<ExtractDraft> drafts;
  final List<ExtractSectionSummary> sectionSummaries;

  factory ExtractJobResult.fromJson(Map<String, dynamic> json) {
    return ExtractJobResult(
      drafts: [
        for (final item in (json['drafts'] as List? ?? const []))
          if (item is Map)
            ExtractDraft.fromJson(Map<String, dynamic>.from(item)),
      ],
      sectionSummaries: [
        for (final item in (json['section_summaries'] as List? ?? const []))
          if (item is Map)
            ExtractSectionSummary.fromJson(Map<String, dynamic>.from(item)),
      ],
    );
  }
}
