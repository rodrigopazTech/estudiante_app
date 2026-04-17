import 'package:googleapis/calendar/v3.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import '../main.dart'; // Para acceder a googleSignIn global

class CalendarService {
  // Cliente HTTP autenticado para Google APIs
  static Future<AuthClient?> _getAuthClient() async {
    final googleUser = googleSignIn.currentUser;
    if (googleUser == null) return null;

    final auth = await googleUser.authentication;
    final token = auth.accessToken;

    if (token == null) return null;

    final credentials = AccessToken('Bearer', token, DateTime.now().add(const Duration(hours: 1)).toUtc());
    return authenticatedClient(http.Client(), AccessCredentials(credentials, null, []));
  }

  static Future<void> syncClassesToGoogleCalendar(List<Map<String, dynamic>> classes) async {
    final client = await _getAuthClient();
    if (client == null) return;

    try {
      final calendarApi = CalendarApi(client);
      
      // 1. Obtener eventos existentes para evitar duplicados
      final existingEvents = await calendarApi.events.list('primary', q: 'Flutter Clase');
      final existingTitles = existingEvents.items?.map((e) => e.summary).toSet() ?? {};

      for (final cls in classes) {
        final title = cls['title'] as String;
        
        // 2. Si la clase no está en el calendario, la insertamos
        if (!existingTitles.contains(title)) {
          final event = Event()
            ..summary = title
            ..description = cls['description']
            ..location = cls['meetLink']
            ..start = (EventDateTime()
              ..dateTime = (cls['dateTime'] as DateTime).toUtc())
            ..end = (EventDateTime()
              ..dateTime = (cls['dateTime'] as DateTime).add(const Duration(hours: 1)).toUtc())
            ..reminders = (EventReminders()
              ..useDefault = false
              ..overrides = [
                EventReminder()..method = 'popup'..minutes = 15, // Avisar 15 min antes
              ]);

          await calendarApi.events.insert(event, 'primary');
          print('✅ Clase agendada: $title');
        }
      }
    } catch (e) {
      print('❌ Error sincronizando calendario: $e');
    } finally {
      client.close();
    }
  }
}
