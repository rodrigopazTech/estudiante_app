import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

class MarkdownViewerScreen extends StatelessWidget {
  final String markdown;
  final String title;

  const MarkdownViewerScreen({
    super.key,
    required this.markdown,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final codeBlockColor =
        isDark ? AppTheme.darkSurfaceCard2 : const Color(0xFFF1F3FE);

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: isDark ? AppTheme.darkSurfaceCard : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: cs.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          title,
          style: GoogleFonts.plusJakartaSans(
            color: cs.onSurface,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: Markdown(
        data: markdown,
        selectable: true,
        styleSheet: MarkdownStyleSheet(
          h1: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w800,
            fontSize: 24,
            color: cs.onSurface,
          ),
          h2: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w700,
            fontSize: 20,
            color: cs.onSurface,
          ),
          p: GoogleFonts.inter(
            fontSize: 15,
            color: cs.onSurfaceVariant,
            height: 1.6,
          ),
          code: GoogleFonts.firaCode(
            backgroundColor: codeBlockColor,
            fontSize: 14,
            color: isDark ? cs.primary : const Color(0xFF181C23),
          ),
          codeblockDecoration: BoxDecoration(
            color: codeBlockColor,
            borderRadius: BorderRadius.circular(12),
          ),
          blockquoteDecoration: BoxDecoration(
            color: cs.primary.withOpacity(0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border(
              left: BorderSide(color: cs.primary, width: 3),
            ),
          ),
          blockquote: GoogleFonts.inter(
            color: cs.onSurfaceVariant,
            fontStyle: FontStyle.italic,
          ),
          horizontalRuleDecoration: BoxDecoration(
            border: Border(
              top: BorderSide(
                color: cs.outlineVariant.withOpacity(0.4),
                width: 1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
