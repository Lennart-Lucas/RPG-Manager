import 'package:flutter/material.dart';

import '../../auth/state/auth_controller.dart';
import '../data/catalog_wiki_resolve.dart';
import '../ui/open_catalog_detail.dart';
import '../../../core/ui/simple_card_rich_text.dart';

/// [SimpleCardRichText] wired to catalog wiki links and `![[…]]` embeds.
class CatalogRichText extends StatelessWidget {
  const CatalogRichText({
    super.key,
    required this.auth,
    required this.content,
    this.baseStyle,
    this.styleScale = 1.0,
    this.enableSelection = true,
  });

  final AuthController auth;
  final String content;
  final TextStyle? baseStyle;
  final double styleScale;
  final bool enableSelection;

  @override
  Widget build(BuildContext context) {
    return SimpleCardRichText(
      content: content,
      baseStyle: baseStyle,
      styleScale: styleScale,
      enableSelection: enableSelection,
      onWikiLinkTap: (kind, name) => openCatalogWikiLink(
        context: context,
        auth: auth,
        kindApiValue: kind,
        name: name,
      ),
      resolveWikiEmbed: (kind, name, {alias}) async {
        final embed = await resolveCatalogEmbed(
          auth: auth,
          kindApiValue: kind,
          name: name,
          alias: alias,
        );
        if (embed == null) return null;
        return CatalogEmbedPayload(title: embed.title, body: embed.body);
      },
    );
  }
}
