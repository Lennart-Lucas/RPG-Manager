import 'package:flutter/material.dart';

import '../../../auth/data/auth_api.dart';
import '../../../auth/state/auth_controller.dart';
import '../../resources/data/resource_models.dart';
import '../data/anthropic_key_store.dart';
import '../data/extract_api.dart';
import '../data/extract_models.dart';
import '../data/pdf_text_extractor.dart';
import 'extract_options_dialog.dart';
import 'condition_extract_review_page.dart';
import 'item_extract_review_page.dart';
import 'spell_extract_review_page.dart';

/// Runs PDF text extraction + backend extract job(s), then opens review.
Future<void> startExtraction({
  required BuildContext context,
  required AuthController auth,
  required ResourceFile file,
  required String localPath,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final aiEnabled = auth.user?.aiIntegration ?? false;
  if (!aiEnabled) {
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Enable AI integration in Preferences first'),
      ),
    );
    return;
  }

  final keyStore = AnthropicKeyStore();
  final apiKey = await keyStore.read();
  if (apiKey == null || apiKey.trim().isEmpty) {
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Add your Anthropic API key in Preferences'),
      ),
    );
    return;
  }

  final extractor = PdfTextExtractor();
  int pageCount;
  try {
    pageCount = await extractor.pageCount(localPath);
  } catch (e) {
    messenger.showSnackBar(
      SnackBar(content: Text('Could not open PDF: $e')),
    );
    return;
  }
  if (pageCount < 1) {
    messenger.showSnackBar(
      const SnackBar(content: Text('This PDF has no pages')),
    );
    return;
  }

  if (!context.mounted) return;
  final options = await showExtractOptionsDialog(
    context: context,
    pageCount: pageCount,
  );
  if (options == null || !context.mounted) return;
  if (options.kinds.isEmpty) return;

  final kinds = options.kinds.toList();
  final kindLabels = kinds.map((k) => k.label.toLowerCase()).join(' & ');

  if (!context.mounted) return;
  final progressMessage = ValueNotifier<String>(
    'Extracting $kindLabels from pages '
    '${options.startPage}–${options.endPage}…',
  );
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      content: Row(
        children: [
          const CircularProgressIndicator(),
          const SizedBox(width: 20),
          Expanded(
            child: ValueListenableBuilder<String>(
              valueListenable: progressMessage,
              builder: (context, message, _) => Text(message),
            ),
          ),
        ],
      ),
    ),
  );

  try {
    final text = await extractor.extractFromFile(
      localPath,
      startPage: options.startPage,
      endPage: options.endPage,
      onProgress: ({required page, required endPage, required usedOcr}) {
        final mode = usedOcr ? 'OCR' : 'text';
        progressMessage.value =
            'Reading page $page of $endPage ($mode)…';
      },
    );
    if (!pdfExportHasBodyText(text)) {
      if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
      messenger.showSnackBar(
        const SnackBar(content: Text(kPdfNoExtractableTextMessage)),
      );
      return;
    }

    final token = await auth.requireAccessToken();
    if (token == null) {
      if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
      return;
    }

    final api = ExtractApi();
    final results = <ExtractRecordKind, ExtractJobResult>{};
    for (final kind in kinds) {
      results[kind] = await api.createJob(
        accessToken: token,
        anthropicApiKey: apiKey,
        text: text,
        kind: kind.apiValue,
        documentTitle: file.name,
        sourceFileId: file.id,
      );
    }

    if (!context.mounted) return;
    Navigator.of(context, rootNavigator: true).pop();

    var openedAny = false;
    for (final kind in kinds) {
      final result = results[kind];
      if (result == null || result.drafts.isEmpty) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('No ${kind.label.toLowerCase()} entries were extracted'),
          ),
        );
        continue;
      }
      if (!context.mounted) return;
      openedAny = true;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (context) => switch (kind) {
            ExtractRecordKind.spells => SpellExtractReviewPage(
                auth: auth,
                sourceFile: file,
                localPath: localPath,
                drafts: result.drafts,
                sectionSummaries: result.sectionSummaries,
              ),
            ExtractRecordKind.items => ItemExtractReviewPage(
                auth: auth,
                sourceFile: file,
                localPath: localPath,
                drafts: result.drafts,
                sectionSummaries: result.sectionSummaries,
              ),
            ExtractRecordKind.conditions => ConditionExtractReviewPage(
                auth: auth,
                sourceFile: file,
                localPath: localPath,
                drafts: result.drafts,
                sectionSummaries: result.sectionSummaries,
              ),
          },
        ),
      );
    }

    if (!openedAny && context.mounted) {
      // Already snacked per kind; nothing else.
    }
  } on AuthApiException catch (e) {
    if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
    messenger.showSnackBar(SnackBar(content: Text(e.message)));
  } catch (e) {
    if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
    messenger.showSnackBar(
      SnackBar(content: Text('Extraction failed: $e')),
    );
  }
}

/// Back-compat alias for spell-only callers.
Future<void> startSpellExtraction({
  required BuildContext context,
  required AuthController auth,
  required ResourceFile file,
  required String localPath,
}) {
  return startExtraction(
    context: context,
    auth: auth,
    file: file,
    localPath: localPath,
  );
}
