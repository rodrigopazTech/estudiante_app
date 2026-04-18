import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';

import '../main.dart';
import '../theme/app_theme.dart';
import 'code_viewer_screen.dart';
import 'markdown_viewer_screen.dart';

class DriveExplorerScreen extends StatefulWidget {
  final String folderUrl;
  final String title;
  final String mode;

  const DriveExplorerScreen({
    super.key,
    required this.folderUrl,
    required this.title,
    required this.mode,
  });

  @override
  State<DriveExplorerScreen> createState() => _DriveExplorerScreenState();
}

class _DriveExplorerScreenState extends State<DriveExplorerScreen> {
  List<dynamic> _files = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchFiles();
  }

  String _extractFolderId(String url) {
    final regExp = RegExp(r'folders/([a-zA-Z0-9-_]+)');
    final match = regExp.firstMatch(url);
    return match?.group(1) ?? '';
  }

  Future<void> _fetchFiles() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final googleUser = googleSignIn.currentUser;
      if (googleUser == null) throw Exception('Usuario no autenticado');

      final auth = await googleUser.authentication;
      final token = auth.accessToken;

      final folderId = _extractFolderId(widget.folderUrl);
      if (folderId.isEmpty) throw Exception('Link de Drive inválido');

      final response = await http.get(
        Uri.parse(
            'https://www.googleapis.com/drive/v3/files?q=%27$folderId%27+in+parents+and+trashed=false&fields=files(id,name,mimeType,webViewLink,iconLink)'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        List<dynamic> allFiles = data['files'] ?? [];

        if (widget.mode == 'code') {
          _files = allFiles.where((f) {
            final name = f['name'].toString().toLowerCase();
            return name.endsWith('.dart') ||
                name.endsWith('.js') ||
                name.endsWith('.ts') ||
                name.endsWith('.json') ||
                name.endsWith('.html') ||
                name.endsWith('.css');
          }).toList();
        } else {
          _files = allFiles.where((f) {
            final name = f['name'].toString().toLowerCase();
            return name.endsWith('.md') ||
                name.endsWith('.pdf') ||
                name.endsWith('.doc') ||
                name.endsWith('.docx') ||
                f['mimeType'].toString().contains('google-apps.document');
          }).toList();
        }

        setState(() => _isLoading = false);
      } else {
        throw Exception('Error al conectar con Drive API');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _openFile(Map<String, dynamic> file) async {
    final name = file['name'].toString();
    final id = file['id'].toString();

    if (name.endsWith('.dart') ||
        name.endsWith('.js') ||
        name.endsWith('.ts') ||
        name.endsWith('.json') ||
        name.endsWith('.md')) {
      _viewNatively(id, name);
    } else {
      final url = Uri.parse(file['webViewLink']);
      if (await canLaunchUrl(url)) {
        await launchUrl(url);
      }
    }
  }

  Future<void> _viewNatively(String fileId, String fileName) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final googleUser = googleSignIn.currentUser;
      final auth = await googleUser!.authentication;
      final token = auth.accessToken;

      final response = await http.get(
        Uri.parse('https://www.googleapis.com/drive/v3/files/$fileId?alt=media'),
        headers: {'Authorization': 'Bearer $token'},
      );

      Navigator.pop(context);
      if (!mounted) return;

      if (response.statusCode == 200) {
        if (fileName.endsWith('.md')) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => MarkdownViewerScreen(
                markdown: response.body,
                title: fileName,
              ),
            ),
          );
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CodeViewerScreen(
                code: response.body,
                fileName: fileName,
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al descargar archivo: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
          widget.mode == 'code' ? 'Archivos de Código' : 'Documentos',
          style: GoogleFonts.plusJakartaSans(
            color: cs.onSurface,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.share_outlined, color: cs.primary),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: widget.folderUrl));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('🔗 Link copiado al portapapeles'),
                    backgroundColor: cs.primary,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                );
              }
            },
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: cs.primary))
          : _error != null
              ? Center(
                  child: Text(_error!,
                      style: TextStyle(color: cs.onSurfaceVariant)))
              : _files.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.folder_open_rounded,
                              size: 64,
                              color: cs.onSurfaceVariant.withOpacity(0.35)),
                          const SizedBox(height: 16),
                          Text(
                            'No se encontraron archivos.',
                            style: GoogleFonts.inter(
                                color: cs.onSurfaceVariant),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(20),
                      itemCount: _files.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final file = _files[index];
                        return _buildFileItem(file, cs, isDark);
                      },
                    ),
    );
  }

  Widget _buildFileItem(
      Map<String, dynamic> file, ColorScheme cs, bool isDark) {
    final name = file['name'].toString();
    IconData iconData = Icons.insert_drive_file_rounded;
    Color iconColor = cs.onSurfaceVariant;

    if (name.endsWith('.dart')) {
      iconData = Icons.code_rounded;
      iconColor = cs.primary;
    } else if (name.endsWith('.md')) {
      iconData = Icons.description_rounded;
      iconColor = cs.tertiary;
    } else if (name.endsWith('.js') || name.endsWith('.ts')) {
      iconData = Icons.code_rounded;
      iconColor = cs.secondary;
    }

    return GestureDetector(
      onTap: () => _openFile(file),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSurfaceCard : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? cs.primary.withOpacity(0.06)
                  : const Color(0xFF181C23).withOpacity(0.04),
              blurRadius: isDark ? 20 : 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(isDark ? 0.15 : 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(iconData, color: iconColor, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                name,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: cs.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}
