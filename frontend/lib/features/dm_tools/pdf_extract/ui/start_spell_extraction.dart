import 'package:flutter/material.dart';

import '../../../auth/data/auth_api.dart';
import '../../../auth/state/auth_controller.dart';
import '../../resources/data/resource_models.dart';
import '../data/anthropic_key_store.dart';
import '../data/extract_api.dart';
import '../data/pdf_text_extractor.dart';
import 'extract_options_dialog.dart';
import 'spell_extract_review_page.dart';

/// Runs PDF text extraction + backend extract job, then opens review.
Future<void> startSpellExtraction({
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

  if (!options.kinds.contains(ExtractRecordKind.spells)) {
    messenger.showSnackBar(
      const SnackBar(content: Text('Only spell extraction is available for now')),
    );
    return;
  }

  if (!context.mounted) return;
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      content: Row(
        children: [
          const CircularProgressIndicator(),
          const SizedBox(width: 20),
          Expanded(
            child: Text(
              'Extracting spells from pages '
              '${options.startPage}–${options.endPage}…',
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
    );
    if (text.trim().isEmpty) {
      if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
      messenger.showSnackBar(
        const SnackBar(content: Text('No text found in this page range')),
      );
      return;
    }

    final token = await auth.requireAccessToken();
    if (token == null) {
      if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
      return;
    }

    final result = await ExtractApi().createJob(
      accessToken: token,
      anthropicApiKey: apiKey,
      text: text,
      documentTitle: file.name,
      sourceFileId: file.id,
    );

    if (!context.mounted) return;
    Navigator.of(context, rootNavigator: true).pop();

    if (result.drafts.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('No spell entries were extracted')),
      );
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => SpellExtractReviewPage(
          auth: auth,
          sourceFile: file,
          localPath: localPath,
          drafts: result.drafts,
          sectionSummaries: result.sectionSummaries,
        ),
      ),
    );
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
