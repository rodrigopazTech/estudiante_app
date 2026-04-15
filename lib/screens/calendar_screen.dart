import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_functions/cloud_functions.dart';

class CalendarScreen extends StatelessWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
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

        return ListView.builder(
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final classDoc = snapshot.data!.docs[index];
            final classData = classDoc.data() as Map<String, dynamic>;
            final title = classData['title'] ?? 'Clase sin título';
            final description = classData['description'] ?? 'Sin descripción disponible.';
            final dateTime = (classData['dateTime'] as Timestamp).toDate();
            final meetLink = classData['meetLink'] ?? 'https://meet.google.com/xxx-xxxx-xxx';

            final isFuture = dateTime.isAfter(DateTime.now());

            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ExpansionTile(
                leading: CircleAvatar(
                  backgroundColor: isFuture ? Colors.blue : Colors.grey,
                  child: Text(
                    DateFormat('dd').format(dateTime),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(DateFormat('EEEE, d MMMM - HH:mm', 'es_ES').format(dateTime)),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Contenido de la clase:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(description),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            ElevatedButton.icon(
                              onPressed: () => _launchUrl(meetLink),
                              icon: const Icon(Icons.video_call),
                              label: const Text('Unirse a Meet'),
                            ),
                            const Spacer(),
                            if (isFuture)
                              TextButton.icon(
                                onPressed: () => _showAttendanceDialog(context, classDoc.id),
                                icon: const Icon(Icons.check_circle_outline),
                                label: const Text('Validar Asistencia'),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showAttendanceDialog(BuildContext context, String classId) {
    final TextEditingController codeController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Ingresar código de asistencia'),
          content: TextField(
            controller: codeController,
            decoration: const InputDecoration(
              hintText: 'Código enviado por el instructor',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
            maxLength: 6,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                final code = codeController.text;
                Navigator.pop(context);
                _validateAttendance(context, classId, code);
              },
              child: const Text('Enviar'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _validateAttendance(BuildContext context, String classId, String code) async {
    try {
      final result = await FirebaseFunctions.instance.httpsCallable('validateAttendance').call({
        'classId': classId,
        'code': code,
      });

      if (!context.mounted) return;

      final bool success = result.data['success'] ?? false;
      final String message = result.data['message'] ?? 'Respuesta del servidor no disponible.';

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.green),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al validar asistencia: $e')),
      );
    }
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri)) {
      // ignore: avoid_print
      print('Could not launch $url');
    }
  }
}
