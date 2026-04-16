import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'firebase_options.dart';

import 'screens/calendar_screen.dart';
import 'screens/materials_screen.dart';
import 'screens/profile_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es_ES', null);
  
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const EstudianteApp());
}

class EstudianteApp extends StatelessWidget {
  const EstudianteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Estudiante App',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0058BC),
          surface: const Color(0xFFF9F9FF),
          primary: const Color(0xFF0058BC),
          onPrimary: Colors.white,
          onSurface: const Color(0xFF181C23),
        ),
        textTheme: GoogleFonts.interTextTheme(
          Theme.of(context).textTheme,
        ).copyWith(
          displayLarge: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w800,
            color: const Color(0xFF181C23),
          ),
          headlineLarge: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w800,
            color: const Color(0xFF181C23),
          ),
          titleLarge: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w700,
            color: const Color(0xFF181C23),
          ),
        ),
      ),
      home: const AuthWrapper(),
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
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
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
    return Scaffold(
      body: Stack(
        children: [
          // Background blue accent blur
          Positioned(
            top: -100,
            left: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                color: const Color(0xFF0058BC).withOpacity(0.05),
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
                color: const Color(0xFF006B27).withOpacity(0.05),
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
                    // Branding & Iconography
                    Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF181C23).withOpacity(0.06),
                            blurRadius: 40,
                            offset: const Offset(0, 24),
                          ),
                        ],
                      ),
                      transform: Matrix4.rotationZ(-0.05),
                      child: const Icon(
                        Icons.school_rounded,
                        size: 60,
                        color: Color(0xFF0058BC),
                      ),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      'Estudiante App',
                      style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                            fontSize: 40,
                            letterSpacing: -1.0,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tu portal de aprendizaje',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: const Color(0xFF414755).withOpacity(0.8),
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                    const SizedBox(height: 48),
                    // Login Card
                    Container(
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: const Color(0xFFC1C6D7).withOpacity(0.1),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF181C23).withOpacity(0.04),
                            blurRadius: 48,
                            offset: const Offset(0, 24),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          // Graphic Placeholder
                          Container(
                            height: 160,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              image: const DecorationImage(
                                image: NetworkImage(
                                    'https://lh3.googleusercontent.com/aida-public/AB6AXuCPsZ46oVLOdNPauz4Ad-OiQNMxeuIchxFVBaP4QqImVNrHE4B8yfwgHYfx1FzTQWPA-CYLDVMUBlGPz1xIl62yHOZqUlf7tn8ye3id3YQJC7PahUazxQfaVk9Kyae9ISHPf-UKkwewhBMZQOybBlzKk0P839ylxcxTmV0eh8HnMW-L0ozRh5PsCxQeyaoRmOKLr36uHG5vB9VvCmHrlExjJvOzgZYlPY_EQ4jZ6DWbd3HLicNCSfQP_fblPTeWXAuMoV1aT9Py6W1s'),
                                fit: BoxFit.cover,
                                opacity: 0.2,
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          // Primary CTA
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton(
                              onPressed: () => _signInWithGoogle(context),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0058BC),
                                foregroundColor: Colors.white,
                                elevation: 4,
                                shadowColor: const Color(0xFF0058BC).withOpacity(0.4),
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
                                  const Text(
                                    'Entrar con Google',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
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
                                  color: const Color(0xFFC1C6D7).withOpacity(0.3),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                child: Text(
                                  'O',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF717786),
                                    letterSpacing: 2.0,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Divider(
                                  color: const Color(0xFFC1C6D7).withOpacity(0.3),
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
                              icon: const Icon(Icons.mail_outline_rounded),
                              label: const Text('Usar correo institucional'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF414755),
                                side: BorderSide.none,
                                backgroundColor: const Color(0xFFF1F3FE),
                                shape: const StadiumBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 48),
                    // Featurette
                    Row(
                      children: [
                        Expanded(
                          child: _buildFeatureCard(
                            context,
                            Icons.workspace_premium_rounded,
                            'Certificado\nOficial',
                            const Color(0xFF006B27),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildFeatureCard(
                            context,
                            Icons.speed_rounded,
                            'Ritmo\nÁgil',
                            const Color(0xFF405E96),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 40),
                    // Footer
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildFooterLink('Ayuda'),
                        const SizedBox(width: 24),
                        _buildFooterLink('Privacidad'),
                        const SizedBox(width: 24),
                        _buildFooterLink('Términos'),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '© 2024 Estudiante App. Todos los derechos reservados.',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: const Color(0xFF414755).withOpacity(0.4),
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

  Widget _buildFeatureCard(BuildContext context, IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Text(
            text,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: color.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooterLink(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: const Color(0xFF414755).withOpacity(0.6),
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
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Estudiante App',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w800,
            fontSize: 22,
          ),
        ),
        backgroundColor: const Color(0xFFF1F3FE),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => FirebaseAuth.instance.signOut(),
          ),
        ],
      ),
      body: _screens[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) => setState(() => _selectedIndex = index),
        indicatorColor: const Color(0xFFA1BEFD),
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
