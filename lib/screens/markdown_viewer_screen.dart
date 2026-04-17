import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_fonts/google_fonts.dart';

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
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF181C23)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          title,
          style: GoogleFonts.plusJakartaSans(
            color: const Color(0xFF181C23),
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
            color: const Color(0xFF181C23),
          ),
          h2: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w700,
            fontSize: 20,
            color: const Color(0xFF181C23),
          ),
          p: GoogleFonts.inter(
            fontSize: 15,
            color: const Color(0xFF414755),
            height: 1.6,
          ),
          code: GoogleFonts.firaCode(
            backgroundColor: const Color(0xFFF1F3FE),
            fontSize: 14,
          ),
          codeblockDecoration: BoxDecoration(
            color: const Color(0xFFF1F3FE),
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}
