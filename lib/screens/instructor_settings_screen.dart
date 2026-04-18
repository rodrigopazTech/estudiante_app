import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

class InstructorSettingsScreen extends StatefulWidget {
  final String userId;
  const InstructorSettingsScreen({super.key, required this.userId});

  @override
  State<InstructorSettingsScreen> createState() =>
      _InstructorSettingsScreenState();
}

class _InstructorSettingsScreenState extends State<InstructorSettingsScreen> {
  bool _emailEnabled = true;
  bool _pushEnabled = true;
  bool _loading = true;
  bool _saving = false;

  late final DocumentReference _settingsRef;

  @override
  void initState() {
    super.initState();
    _settingsRef = FirebaseFirestore.instance
        .collection('instructorSettings')
        .doc(widget.userId);
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final doc = await _settingsRef.get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        setState(() {
          _emailEnabled = data['emailEnabled'] ?? true;
          _pushEnabled = data['pushEnabled'] ?? true;
        });
      }
    } catch (e) {
      // Documento puede no existir todavía, valores por defecto
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _saveSettings() async {
    setState(() => _saving = true);

    try {
      final fcmToken = await FirebaseMessaging.instance.getToken();

      await _settingsRef.set({
        'role': 'instructor',
        'emailEnabled': _emailEnabled,
        'pushEnabled': _pushEnabled,
        'fcmToken': fcmToken,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        final cs = Theme.of(context).colorScheme;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('✅ Ajustes guardados correctamente'),
            backgroundColor: cs.tertiary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: Text(
          'Ajustes de instructor',
          style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w700, color: cs.onSurface),
        ),
        backgroundColor: isDark ? AppTheme.darkSurfaceCard : cs.surface,
        elevation: 0,
        iconTheme: IconThemeData(color: cs.onSurface),
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: cs.primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header gradient
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isDark
                            ? [AppTheme.darkSurfaceCard2, AppTheme.darkSurfaceCard]
                            : [const Color(0xFF0058BC), const Color(0xFF005BAA)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: cs.primary.withOpacity(isDark ? 0.2 : 0.15),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                      border: isDark
                          ? Border.all(color: cs.primary.withOpacity(0.2))
                          : null,
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.notifications_active_rounded,
                            color: isDark ? cs.primary : Colors.white,
                            size: 32,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Notificaciones de código',
                                style: GoogleFonts.plusJakartaSans(
                                  color: isDark ? cs.onSurface : Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Elige cómo quieres recibir el código 1 hora antes de cada clase.',
                                style: GoogleFonts.inter(
                                  color: isDark
                                      ? cs.onSurfaceVariant
                                      : Colors.white.withOpacity(0.75),
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),
                  Text(
                    'Canales de notificación',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: cs.onSurfaceVariant,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 12),

                  _buildToggleTile(
                    context: context,
                    cs: cs,
                    isDark: isDark,
                    icon: Icons.email_outlined,
                    color: const Color(0xFFFF9800),
                    title: 'Notificación por correo',
                    subtitle:
                        'Recibirás un correo con el código y el nombre de la clase.',
                    value: _emailEnabled,
                    onChanged: (val) => setState(() => _emailEnabled = val),
                  ),

                  const SizedBox(height: 12),

                  _buildToggleTile(
                    context: context,
                    cs: cs,
                    isDark: isDark,
                    icon: Icons.phone_android_rounded,
                    color: cs.primary,
                    title: 'Notificación push',
                    subtitle:
                        'Recibirás una notificación en este dispositivo con el código.',
                    value: _pushEnabled,
                    onChanged: (val) => setState(() => _pushEnabled = val),
                  ),

                  const SizedBox(height: 40),

                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _saving ? null : _saveSettings,
                      icon: _saving
                          ? SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: cs.onPrimary),
                            )
                          : Icon(Icons.save_rounded, color: cs.onPrimary),
                      label: Text(
                        _saving ? 'Guardando...' : 'Guardar ajustes',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: cs.onPrimary,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: cs.primary,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        elevation: isDark ? 0 : 2,
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Info box
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppTheme.darkSurfaceCard
                          : const Color(0xFFFFFDE7),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark
                            ? cs.tertiary.withOpacity(0.25)
                            : const Color(0xFFFFE082),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline_rounded,
                            color: isDark ? cs.tertiary : Colors.amber.shade700,
                            size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'El sistema verifica tu calendario cada 15 minutos. Si creas una clase con menos de 1 hora de anticipación, el código se generará en el siguiente ciclo.',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: isDark ? cs.onSurfaceVariant : Colors.black87,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildToggleTile({
    required BuildContext context,
    required ColorScheme cs,
    required bool isDark,
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurfaceCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? cs.primary.withOpacity(0.06)
                : Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: SwitchListTile.adaptive(
        secondary: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(isDark ? 0.15 : 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color),
        ),
        title: Text(
          title,
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            color: cs.onSurface,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            subtitle,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: cs.onSurfaceVariant,
            ),
          ),
        ),
        value: value,
        onChanged: onChanged,
        activeColor: cs.primary,
        isThreeLine: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    );
  }
}
