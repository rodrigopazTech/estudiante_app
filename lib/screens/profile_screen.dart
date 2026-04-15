import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'instructor_settings_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Center(child: Text('No has iniciado sesión.'));
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Center(child: Text('Cargando perfil...'));
        }

        final userData = snapshot.data!.data() as Map<String, dynamic>;
        final streak = userData['streak'] ?? 0;
        final totalAttendance = userData['totalAttendance'] ?? 0;
        final isInstructor = userData['role'] == 'instructor';

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              CircleAvatar(
                radius: 60,
                backgroundImage: NetworkImage(user.photoURL ?? 'https://via.placeholder.com/150'),
              ),
              const SizedBox(height: 20),
              Text(
                user.displayName ?? 'Estudiante',
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              Text(
                user.email ?? '',
                style: const TextStyle(color: Colors.grey),
              ),
              if (isInstructor) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Instructor',
                    style: TextStyle(
                      color: Colors.blue.shade800,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 40),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildStatCard('Racha actual', '$streak', Icons.local_fire_department, Colors.orange),
                  _buildStatCard('Asistencias', '$totalAttendance', Icons.check_circle, Colors.green),
                ],
              ),
              const SizedBox(height: 40),
              const Text(
                'Misión del Curso',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Text(
                  'Desarrollar apps que motiven a aprender y facilitar la consulta de materiales.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontStyle: FontStyle.italic),
                ),
              ),

              // Botón de ajustes del instructor (solo visible para instructores)
              if (isInstructor) ...[
                const SizedBox(height: 20),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.tune, color: Colors.blue),
                  title: const Text('Ajustes de notificaciones'),
                  subtitle: const Text('Configura cómo recibes los códigos de clase'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => InstructorSettingsScreen(userId: user.uid),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 40),
            const SizedBox(height: 8),
            Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            Text(label, style: const TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}
