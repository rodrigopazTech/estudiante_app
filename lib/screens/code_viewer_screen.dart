import 'package:flutter/material.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/atom-one-dark.dart';
import 'package:google_fonts/google_fonts.dart';

class CodeViewerScreen extends StatelessWidget {
  final String code;
  final String fileName;

  const CodeViewerScreen({
    super.key,
    required this.code,
    required this.fileName,
  });

  String _getLanguage() {
    if (fileName.endsWith('.dart')) return 'dart';
    if (fileName.endsWith('.js')) return 'javascript';
    if (fileName.endsWith('.ts')) return 'typescript';
    if (fileName.endsWith('.json')) return 'json';
    if (fileName.endsWith('.html')) return 'xml';
    if (fileName.endsWith('.css')) return 'css';
    return 'plaintext';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF282C34),
      appBar: AppBar(
        backgroundColor: const Color(0xFF21252B),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              fileName,
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              'Visualizador de Código',
              style: GoogleFonts.inter(
                color: Colors.white.withOpacity(0.5),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: HighlightView(
            code,
            language: _getLanguage(),
            theme: atomOneDarkTheme,
            padding: const EdgeInsets.all(16),
            textStyle: GoogleFonts.firaCode(
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}
