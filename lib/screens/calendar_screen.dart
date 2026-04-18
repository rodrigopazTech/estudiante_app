import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/app_theme.dart';

class CalendarScreen extends StatelessWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: cs.surface,
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('classes')
            .orderBy('dateTime', descending: false)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No hay clases programadas.'));
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Momentum Engine Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'YOUR MOMENTUM',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: cs.primary,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Weekly Schedule',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            color: cs.onSurface,
                            letterSpacing: -1.0,
                          ),
                        ),
                      ],
                    ),
                    // Streak Badge (Real data from user profile if possible)
                    _buildStreakBadge(user?.uid),
                  ],
                ),
                const SizedBox(height: 32),

                // Class Cards List
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    final classDoc = snapshot.data!.docs[index];
                    final classData = classDoc.data() as Map<String, dynamic>;
                    final title = classData['title'] ?? 'Clase sin título';
                    final description =
                        classData['description'] ?? 'Sin descripción disponible.';
                    final dateTime = (classData['dateTime'] as Timestamp).toDate();
                    final meetLink =
                        classData['meetLink'] ?? 'https://meet.google.com/xxx';

                    final now = DateTime.now();
                    final isToday = dateTime.day == now.day &&
                        dateTime.month == now.month &&
                        dateTime.year == now.year;
                    final isActive = isToday &&
                        now.isAfter(dateTime) &&
                        now.isBefore(dateTime.add(const Duration(hours: 2)));
                    final isFuture = dateTime.isAfter(now);

                    return _buildClassCard(
                      context,
                      classId: classDoc.id,
                      title: title,
                      description: description,
                      dateTime: dateTime,
                      meetLink: meetLink,
                      isActive: isActive,
                      isToday: isToday,
                      isFuture: isFuture,
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

  Widget _buildStreakBadge(String? userId) {
    return StreamBuilder<DocumentSnapshot>(
      stream: userId != null
          ? FirebaseFirestore.instance.collection('users').doc(userId).snapshots()
          : null,
      builder: (context, snapshot) {
        final streak = (snapshot.hasData && snapshot.data!.exists)
            ? (snapshot.data!.data() as Map<String, dynamic>)['streak'] ?? 0
            : 0;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF72FE88),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF006B27).withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.local_fire_department_rounded,
                  color: Color(0xFF006B27), size: 20),
              const SizedBox(width: 8),
              Text(
                '$streak Day Streak',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF006B27),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildClassCard(
    BuildContext context, {
    required String classId,
    required String title,
    required String description,
    required DateTime dateTime,
    required String meetLink,
    required bool isActive,
    required bool isToday,
    required bool isFuture,
  }) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dateStr = DateFormat('MMM dd').format(dateTime);
    final timeStr =
        '${DateFormat('hh:mm a').format(dateTime)} - ${DateFormat('hh:mm a').format(dateTime.add(const Duration(hours: 1, minutes: 30)))}';

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark
            ? (isActive ? AppTheme.darkSurfaceCard2 : AppTheme.darkSurfaceCard)
            : (isActive ? Colors.white : const Color(0xFFF1F3FE)),
        borderRadius: BorderRadius.circular(24),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: isDark
                      ? cs.primary.withOpacity(0.12)
                      : const Color(0xFF181C23).withOpacity(0.04),
                  blurRadius: isDark ? 40 : 30,
                  offset: const Offset(0, 8),
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    dateStr,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: cs.primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    title,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: cs.onSurface,
                      height: 1.1,
                    ),
                  ),
                ],
              ),
              if (isActive)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD8E2FF),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'ACTIVE NOW',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0058BC),
                    ),
                  ),
                )
              else if (isToday)
                const Text(
                  'NEXT',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF717786),
                    letterSpacing: 1.0,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(Icons.schedule_rounded,
                  color: cs.onSurfaceVariant, size: 16),
              const SizedBox(width: 8),
              Text(
                timeStr,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            description,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: cs.onSurfaceVariant.withOpacity(0.85),
              height: 1.5,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: isActive ? () => _launchUrl(meetLink) : null,
                  icon: Icon(
                    Icons.videocam_rounded,
                    size: 18,
                    color: isActive
                        ? cs.onPrimary
                        : cs.onSurfaceVariant,
                  ),
                  label: Text(
                    'Unirse a Meet',
                    style: TextStyle(
                      color: isActive
                          ? cs.onPrimary
                          : cs.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isActive
                        ? cs.primary
                        : cs.surfaceContainerLow,
                    disabledBackgroundColor: isDark
                        ? AppTheme.darkSurfaceCard2
                        : Colors.grey.shade200,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: const StadiumBorder(),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: isActive || isFuture
                      ? () => _showAttendanceDialog(context, classId)
                      : null,
                  icon: Icon(
                    Icons.check_circle_rounded,
                    size: 18,
                    color: (isActive || isFuture)
                        ? cs.onSecondaryContainer
                        : cs.onSurfaceVariant,
                  ),
                  label: Text(
                    'Validar Asistencia',
                    style: TextStyle(
                      color: (isActive || isFuture)
                          ? cs.onSecondaryContainer
                          : cs.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: (isActive || isFuture)
                        ? cs.secondaryContainer
                        : cs.surfaceContainerLow,
                    disabledBackgroundColor: isDark
                        ? AppTheme.darkSurfaceCard2
                        : Colors.grey.shade200,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: const StadiumBorder(),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showAttendanceDialog(BuildContext context, String classId) {
    final List<TextEditingController> controllers =
        List.generate(6, (index) => TextEditingController());
    final List<FocusNode> focusNodes = List.generate(6, (index) => FocusNode());
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkSurfaceCard : Colors.white,
              borderRadius: BorderRadius.circular(32),
              boxShadow: [
                BoxShadow(
                  color: isDark
                      ? cs.primary.withOpacity(0.15)
                      : Colors.black.withOpacity(0.1),
                  blurRadius: 40,
                  offset: const Offset(0, 20),
                ),
              ],
              border: isDark
                  ? Border.all(color: cs.primary.withOpacity(0.15))
                  : null,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: cs.primary.withOpacity(isDark ? 0.15 : 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.fingerprint_rounded,
                      color: cs.primary, size: 32),
                ),
                const SizedBox(height: 24),
                Text(
                  'Validar Asistencia',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Ingresa el código de 6 dígitos proporcionado por tu docente.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 32),
                // Code Input Fields
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(6, (index) {
                    return SizedBox(
                      width: 45,
                      height: 56,
                      child: TextField(
                        controller: controllers[index],
                        focusNode: focusNodes[index],
                        textAlign: TextAlign.center,
                        keyboardType: TextInputType.number,
                        maxLength: 1,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: cs.onSurface,
                        ),
                        decoration: InputDecoration(
                          counterText: '',
                          filled: true,
                          fillColor: isDark
                              ? AppTheme.darkSurfaceCard2
                              : const Color(0xFFF1F3FE),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                                color: cs.primary.withOpacity(0.6), width: 2),
                          ),
                        ),
                        onChanged: (value) {
                          if (value.isNotEmpty && index < 5) {
                            focusNodes[index + 1].requestFocus();
                          } else if (value.isEmpty && index > 0) {
                            focusNodes[index - 1].requestFocus();
                          }
                        },
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 32),

                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () {
                      final code =
                          controllers.map((c) => c.text).join();
                      if (code.length == 6) {
                        Navigator.pop(context);
                        _validateAttendance(context, classId, code);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: cs.primary,
                      foregroundColor: cs.onPrimary,
                      shape: const StadiumBorder(),
                      elevation: 0,
                    ),
                    child: Text(
                      'Enviar',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: cs.onPrimary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Cancelar',
                    style: GoogleFonts.inter(
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _validateAttendance(
      BuildContext context, String classId, String code) async {
    try {
      final result = await FirebaseFunctions.instance
          .httpsCallable('validateAttendance')
          .call({
        'classId': classId,
        'code': code,
      });

      if (!context.mounted) return;

      final bool success = result.data['success'] ?? false;
      final String message =
          result.data['message'] ?? 'Respuesta del servidor no disponible.';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: success ? Colors.green : Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al validar asistencia: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri)) {
      debugPrint('Could not launch $url');
    }
  }
}
