import 'package:flutter/material.dart';

import '../../../auth/data/auth_api.dart';
import '../../../auth/state/auth_controller.dart';
import '../../resources/data/resource_models.dart';
import '../data/anthropic_key_store.dart';
import '../data/extract_api.dart';
import '../data/pdf_text_extractor.dart';
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

  if (!context.mounted) return;
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) => const AlertDialog(
      content: Row(
        children: [
          CircularProgressIndicator(),
          SizedBox(width: 20),
          Expanded(child: Text('Extracting spells from PDF…')),
        ],
      ),
    ),
  );

  try {
    final text = await PdfTextExtractor().extractFromFile(localPath);
    if (text.trim().isEmpty) {
      if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
      messenger.showSnackBar(
        const SnackBar(content: Text('No text found in this PDF')),
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
