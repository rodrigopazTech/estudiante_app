import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

class MaterialsScreen extends StatelessWidget {
  const MaterialsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('classes')
          .orderBy('dateTime', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('No hay materiales disponibles todavía.'));
        }

        return ListView.builder(
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final classData = snapshot.data!.docs[index].data() as Map<String, dynamic>;
            final title = classData['title'] ?? 'Clase sin título';
            final recordingLink = classData['recordingLink'];
            final driveLink = classData['driveLink'];
            final docLink = classData['docLink'];

            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ListTile(
                title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Materiales de la sesión'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () => _showMaterialOptions(context, title, recordingLink, driveLink, docLink),
              ),
            );
          },
        );
      },
    );
  }

  void _showMaterialOptions(BuildContext context, String title, String? recording, String? drive, String? doc) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              if (recording != null)
                ListTile(
                  leading: const Icon(Icons.videocam, color: Colors.red),
                  title: const Text('Ver grabación'),
                  onTap: () {
                    Navigator.pop(context);
                    _launchUrl(recording);
                  },
                ),
              if (drive != null)
                ListTile(
                  leading: const Icon(Icons.code, color: Colors.blue),
                  title: const Text('Ver código (Drive)'),
                  onTap: () {
                    Navigator.pop(context);
                    _launchUrl(drive);
                  },
                ),
              if (doc != null)
                ListTile(
                  leading: const Icon(Icons.description, color: Colors.orange),
                  title: const Text('Ver otros documentos'),
                  onTap: () {
                    Navigator.pop(context);
                    _launchUrl(doc);
                  },
                ),
              if (recording == null && drive == null && doc == null)
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text('No hay enlaces cargados para esta clase.'),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri)) {
      // ignore: avoid_print
      print('Could not launch $url');
    }
  }
}
