import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import 'video_player_screen.dart';
import 'drive_explorer_screen.dart';

class MaterialsScreen extends StatelessWidget {
  const MaterialsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: cs.surface,
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('classes')
            .orderBy('dateTime', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(color: cs.primary),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Text(
                'No hay materiales disponibles todavía.',
                style: TextStyle(color: cs.onSurfaceVariant),
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Hero Title Section
                Text(
                  'Repositorio de Materiales',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: cs.onSurface,
                    letterSpacing: -1.0,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Accede a las grabaciones y recursos de tus sesiones académicas.',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 40),

                // Sessions Grid/List
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    final classData =
                        snapshot.data!.docs[index].data() as Map<String, dynamic>;
                    final title = classData['title'] ?? 'Clase sin título';
                    final recordingLink = classData['recordingLink'];
                    final driveLink = classData['driveLink'];
                    final docLink = classData['docLink'];
                    final isFirst = index == 0;

                    if (isFirst) {
                      return _buildFeaturedCard(
                        context,
                        title,
                        recordingLink,
                        driveLink,
                        docLink,
                        cs,
                        isDark,
                      );
                    }

                    return _buildSessionListItem(
                      context,
                      title,
                      recordingLink,
                      driveLink,
                      docLink,
                      cs,
                      isDark,
                    );
                  },
                ),
                const SizedBox(height: 100),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildFeaturedCard(
    BuildContext context,
    String title,
    String? recording,
    String? drive,
    String? doc,
    ColorScheme cs,
    bool isDark,
  ) {
    return GestureDetector(
      onTap: () => _showMaterialOptions(context, title, recording, drive, doc),
      child: Container(
        margin: const EdgeInsets.only(bottom: 24),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSurfaceCard2 : Colors.white,
          borderRadius: BorderRadius.circular(32),
          border: isDark
              ? Border.all(color: cs.primary.withOpacity(0.15))
              : Border.all(color: cs.primary.withOpacity(0.05)),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? cs.primary.withOpacity(0.10)
                  : const Color(0xFF181C23).withOpacity(0.04),
              blurRadius: isDark ? 40 : 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'SEMANA ACTUAL',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: cs.primary,
                    letterSpacing: 1.5,
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: cs.tertiary.withOpacity(isDark ? 0.15 : 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'ÚLTIMA SESIÓN',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: cs.tertiary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: cs.onSurface,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionListItem(
    BuildContext context,
    String title,
    String? recording,
    String? drive,
    String? doc,
    ColorScheme cs,
    bool isDark,
  ) {
    return GestureDetector(
      onTap: () => _showMaterialOptions(context, title, recording, drive, doc),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSurfaceCard : const Color(0xFFF1F3FE),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark
                    ? cs.primary.withOpacity(0.12)
                    : Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: isDark
                    ? [
                        BoxShadow(
                          color: cs.primary.withOpacity(0.15),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: Icon(Icons.event_note_rounded, color: cs.primary, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Materiales de la sesión',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: cs.onSurfaceVariant),
          ],
        ),
      ),
    );
  }

  void _showMaterialOptions(BuildContext context, String title, String? recording,
      String? drive, String? doc) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkSurfaceCard : Colors.white,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(32)),
          ),
          padding: const EdgeInsets.only(top: 12, bottom: 48),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 6,
                decoration: BoxDecoration(
                  color: isDark
                      ? cs.primary.withOpacity(0.25)
                      : const Color(0xFFE6E8F3),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'OPCIONES DE RECURSO',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: cs.primary,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      title,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: cs.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    _buildSheetAction(
                      context,
                      'Ver grabación',
                      'Reproducir video de la sesión',
                      Icons.videocam_rounded,
                      cs.primary,
                      recording != null,
                      cs,
                      isDark,
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => VideoPlayerScreen(
                            videoUrl: recording!,
                            title: title,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildSheetAction(
                      context,
                      'Ver código',
                      'Explorar archivos fuente (.dart, .js)',
                      Icons.code_rounded,
                      cs.onSurfaceVariant,
                      drive != null,
                      cs,
                      isDark,
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => DriveExplorerScreen(
                            folderUrl: drive!,
                            title: title,
                            mode: 'code',
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildSheetAction(
                      context,
                      'Ver documentos',
                      'Slides, PDF y notas de clase',
                      Icons.description_rounded,
                      cs.onSurfaceVariant,
                      drive != null,
                      cs,
                      isDark,
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => DriveExplorerScreen(
                            folderUrl: drive!,
                            title: title,
                            mode: 'docs',
                          ),
                        ),
                      ),
                    ),
                    Divider(
                      height: 32,
                      indent: 16,
                      endIndent: 16,
                      color: cs.outlineVariant.withOpacity(0.4),
                    ),
                    _buildSheetAction(
                      context,
                      'Explorar en Drive',
                      'Abrir carpeta completa en Google Drive',
                      Icons.open_in_new_rounded,
                      cs.onSurfaceVariant,
                      drive != null,
                      cs,
                      isDark,
                      () => _launchUrl(drive!),
                    ),
                    const SizedBox(height: 8),
                    _buildSheetAction(
                      context,
                      'Compartir materiales',
                      'Enviar link de la carpeta a un compañero',
                      Icons.share_outlined,
                      cs.primary,
                      drive != null,
                      cs,
                      isDark,
                      () async {
                        await Clipboard.setData(ClipboardData(
                          text:
                              '¡Hola! Te comparto los materiales de la sesión $title: $drive',
                        ));
                        if (context.mounted) {
                          Navigator.pop(context);
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
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSheetAction(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    Color color,
    bool isEnabled,
    ColorScheme cs,
    bool isDark,
    VoidCallback onTap,
  ) {
    final disabledColor = cs.onSurfaceVariant.withOpacity(0.3);

    return Opacity(
      opacity: isEnabled ? 1.0 : 0.45,
      child: InkWell(
        onTap: isEnabled
            ? () {
                Navigator.pop(context);
                onTap();
              }
            : null,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isEnabled && color == cs.primary
                ? cs.primary.withOpacity(isDark ? 0.08 : 0.05)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: !isEnabled
                      ? (isDark ? AppTheme.darkSurfaceCard2 : Colors.grey.shade200)
                      : color.withOpacity(isDark ? 0.15 : 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  icon,
                  color: !isEnabled ? disabledColor : color,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: !isEnabled ? disabledColor : cs.onSurface,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri)) {
      debugPrint('Could not launch $url');
    }
  }
}
