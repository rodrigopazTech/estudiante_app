import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'screens/calendar_screen.dart';
import 'screens/materials_screen.dart';
import 'screens/profile_screen.dart';
import 'theme/app_theme.dart';
import 'theme/theme_provider.dart';

// Instancia global con permisos de Drive y Calendario
final GoogleSignIn googleSignIn = GoogleSignIn(
  scopes: [
    'https://www.googleapis.com/auth/drive.readonly',
    'https://www.googleapis.com/auth/calendar',
  ],
);



void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: const EstudianteApp(),
    ),
  );
}

Future<void> _initializeApp() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Future.wait([
    Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform),
    initializeDateFormatting('es_ES', null),
  ]);
}

class EstudianteApp extends StatefulWidget {
  const EstudianteApp({super.key});

  @override
  State<EstudianteApp> createState() => _EstudianteAppState();
}

class _EstudianteAppState extends State<EstudianteApp> {
  // ✅ El Future se crea UNA sola vez en initState, no en cada rebuild
  late final Future<void> _initFuture;

  @override
  void initState() {
    super.initState();
    _initFuture = _initializeApp();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Estudiante App',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeProvider.themeMode,
      home: FutureBuilder<void>(
        future: _initFuture, // ✅ Reutiliza el mismo Future, no crea uno nuevo
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const _SplashScreen();
          }
          if (snapshot.hasError) {
            return Scaffold(
              body: Center(child: Text('Error al iniciar: ${snapshot.error}')),
            );
          }
          return const AuthWrapper();
        },
      ),
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF0058BC),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.school_rounded, size: 72, color: Colors.white),
            SizedBox(height: 24),
            Text(
              'Estudiante App',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            SizedBox(height: 32),
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white54),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasData) {
          return const MainNavigation();
        }
        return const LoginScreen();
      },
    );
  }
}

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  static const String _googleIconSvg = '''
<svg viewbox="0 0 24 24">
  <path d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z" fill="#4285F4"/>
  <path d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z" fill="#34A853"/>
  <path d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.07H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.93l2.85-2.22.81-.62z" fill="#FBBC05"/>
  <path d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.07l3.66 2.84c.87-2.6 3.3-4.53 6.16-4.53z" fill="#EA4335"/>
</svg>
''';

  Future<void> _signInWithGoogle(BuildContext context) async {
    try {
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser == null) return;

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
      final User? user = userCredential.user;

      if (user != null) {
        final userDoc = FirebaseFirestore.instance.collection('users').doc(user.uid);
        final docSnapshot = await userDoc.get();

        if (!docSnapshot.exists) {
          await userDoc.set({
            'displayName': user.displayName,
            'email': user.email,
            'photoURL': user.photoURL,
            'streak': 0,
            'totalAttendance': 0,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }

        // Guardar FCM token de TODOS los usuarios (alumnos y instructor)
        // Necesario para enviar notificaciones de reprogramación de clases
        final fcmToken = await FirebaseMessaging.instance.getToken(
  vapidKey: 'BJijRXdDH9UR_nlybbHiihtO477f1m9RzvdxR56gDspRnDRtET7QJNpp4W8SKpQPgXWE5_6GuUNGtniPndqWpMk',
);

        if (fcmToken != null) {
          await userDoc.set(
            {'fcmToken': fcmToken},
            SetOptions(merge: true),
          );
        }

        // Además, si es instructor, también actualizar instructorSettings
        if (fcmToken != null) {
          final settingsDoc = await FirebaseFirestore.instance
              .collection('instructorSettings')
              .doc(user.uid)
              .get();
          if (settingsDoc.exists && settingsDoc.data()?['role'] == 'instructor') {
            await FirebaseFirestore.instance
                .collection('instructorSettings')
                .doc(user.uid)
                .update({'fcmToken': fcmToken});
          }
        }
      }

    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al iniciar sesión: $e')),
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
      body: Stack(
        children: [
          // Background accent orbs
          Positioned(
            top: -100,
            left: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                color: cs.primary.withOpacity(isDark ? 0.08 : 0.05),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            bottom: -50,
            right: -50,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                color: cs.tertiary.withOpacity(isDark ? 0.08 : 0.05),
                shape: BoxShape.circle,
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // App Icon
                    Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        color: isDark ? AppTheme.darkSurfaceCard : Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: isDark
                                ? cs.primary.withOpacity(0.2)
                                : const Color(0xFF181C23).withOpacity(0.06),
                            blurRadius: 40,
                            offset: const Offset(0, 24),
                          ),
                        ],
                      ),
                      transform: Matrix4.rotationZ(-0.05),
                      child: Icon(
                        Icons.school_rounded,
                        size: 60,
                        color: cs.primary,
                      ),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      'Estudiante App',
                      style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                            fontSize: 40,
                            letterSpacing: -1.0,
                            color: cs.onSurface,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tu portal de aprendizaje',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: cs.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                    const SizedBox(height: 48),
                    // Login Card
                    Container(
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: isDark ? AppTheme.darkSurfaceCard : Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: isDark
                              ? cs.primary.withOpacity(0.12)
                              : const Color(0xFFC1C6D7).withOpacity(0.1),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: isDark
                                ? cs.primary.withOpacity(0.08)
                                : const Color(0xFF181C23).withOpacity(0.04),
                            blurRadius: 48,
                            offset: const Offset(0, 24),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          // Hero image
                          Container(
                            height: 160,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              color: isDark
                                  ? AppTheme.darkSurfaceCard2
                                  : const Color(0xFFF1F3FE),
                              image: const DecorationImage(
                                image: NetworkImage(
                                    'https://lh3.googleusercontent.com/aida-public/AB6AXuCPsZ46oVLOdNPauz4Ad-OiQNMxeuIchxFVBaP4QqImVNrHE4B8yfwgHYfx1FzTQWPA-CYLDVMUBlGPz1xIl62yHOZqUlf7tn8ye3id3YQJC7PahUazxQfaVk9Kyae9ISHPf-UKkwewhBMZQOybBlzKk0P839ylxcxTmV0eh8HnMW-L0ozRh5PsCxQeyaoRmOKLr36uHG5vB9VvCmHrlExjJvOzgZYlPY_EQ4jZ6DWbd3HLicNCSfQP_fblPTeWXAuMoV1aT9Py6W1s'),
                                fit: BoxFit.cover,
                                opacity: 0.2,
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          // Google Sign-In button
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton(
                              onPressed: () => _signInWithGoogle(context),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: cs.primary,
                                foregroundColor: cs.onPrimary,
                                elevation: 4,
                                shadowColor: cs.primary.withOpacity(0.4),
                                shape: const StadiumBorder(),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                    ),
                                    child: SvgPicture.string(
                                      _googleIconSvg,
                                      width: 18,
                                      height: 18,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    'Entrar con Google',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                      color: cs.onPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          Row(
                            children: [
                              Expanded(
                                child: Divider(
                                  color: cs.outlineVariant.withOpacity(0.4),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                child: Text(
                                  'O',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: cs.onSurfaceVariant,
                                    letterSpacing: 2.0,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Divider(
                                  color: cs.outlineVariant.withOpacity(0.4),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: OutlinedButton.icon(
                              onPressed: () {},
                              icon: Icon(Icons.mail_outline_rounded,
                                  color: cs.onSurfaceVariant),
                              label: Text(
                                'Usar correo institucional',
                                style: TextStyle(color: cs.onSurfaceVariant),
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: cs.onSurfaceVariant,
                                side: BorderSide.none,
                                backgroundColor: isDark
                                    ? AppTheme.darkSurfaceCard2
                                    : const Color(0xFFF1F3FE),
                                shape: const StadiumBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 48),
                    // Feature cards
                    Row(
                      children: [
                        Expanded(
                          child: _buildFeatureCard(
                            context,
                            Icons.workspace_premium_rounded,
                            'Certificado\nOficial',
                            cs.tertiary,
                            isDark,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildFeatureCard(
                            context,
                            Icons.speed_rounded,
                            'Ritmo\nÁgil',
                            cs.secondary,
                            isDark,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 40),
                    // Footer links
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildFooterLink('Ayuda', cs),
                        const SizedBox(width: 24),
                        _buildFooterLink('Privacidad', cs),
                        const SizedBox(width: 24),
                        _buildFooterLink('Términos', cs),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '© 2024 Estudiante App. Todos los derechos reservados.',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: cs.onSurfaceVariant.withOpacity(0.5),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureCard(BuildContext context, IconData icon, String text,
      Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? color.withOpacity(0.12) : color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: isDark
            ? Border.all(color: color.withOpacity(0.2))
            : null,
      ),
      child: Row(
        children: [
          Icon(icon, color: isDark ? color : color.withOpacity(0.85), size: 24),
          const SizedBox(width: 12),
          Text(
            text,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDark ? color : color.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooterLink(String text, ColorScheme cs) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: cs.onSurfaceVariant.withOpacity(0.6),
      ),
    );
  }
}

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _selectedIndex = 0;

  static const List<Widget> _screens = [
    CalendarScreen(),
    MaterialsScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Estudiante App',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w800,
            fontSize: 22,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.logout, color: cs.onSurface),
            tooltip: 'Cerrar sesión',
            onPressed: () async {
              // disconnect() revoca el token OAuth y limpia la caché de Google
              // para que en el próximo login siempre aparezca el selector de cuentas.
              await googleSignIn.disconnect().catchError((_) {});
              await FirebaseAuth.instance.signOut();
            },
          ),
        ],
      ),
      body: _screens[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) => setState(() => _selectedIndex = index),
        indicatorColor: cs.secondary.withOpacity(0.25),
        backgroundColor: cs.surfaceContainerLow,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
            label: 'Clases',
          ),
          NavigationDestination(
            icon: Icon(Icons.folder_outlined),
            selectedIcon: Icon(Icons.folder),
            label: 'Materiales',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }
}
