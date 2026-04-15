const { onCall, onRequest, HttpsError } = require('firebase-functions/v2/https');
const { onSchedule } = require('firebase-functions/v2/scheduler');
const admin = require('firebase-admin');
const { google } = require('googleapis');

admin.initializeApp();
const db = admin.firestore();

// ─────────────────────────────────────────────
// FUNCIÓN 1: Validar asistencia (llamada por el alumno)
// ─────────────────────────────────────────────
exports.validateAttendance = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Debes iniciar sesión.');
  }

  const { classId, code } = request.data;
  const uid = request.auth.uid;

  if (!classId || !code) {
    throw new HttpsError('invalid-argument', 'Faltan classId o code.');
  }

  const classRef = db.collection('classes').doc(classId);
  const classDoc = await classRef.get();

  if (!classDoc.exists) {
    throw new HttpsError('not-found', 'Clase no encontrada.');
  }

  const classData = classDoc.data();
  const serverCode = classData.attendanceCode;
  const classTime = classData.dateTime.toDate();

  const now = new Date();
  const diffHours = Math.abs(now - classTime) / 36e5;

  if (diffHours > 3) {
    return { success: false, message: 'La validación solo está disponible durante el horario de clase.' };
  }

  if (serverCode !== code) {
    return { success: false, message: 'Código de asistencia incorrecto.' };
  }

  // Verificar si ya registró asistencia
  const existing = await db.collection('attendance')
    .where('uid', '==', uid)
    .where('classId', '==', classId)
    .get();

  if (!existing.empty) {
    return { success: false, message: 'Ya has registrado tu asistencia para esta clase.' };
  }

  // Registrar asistencia
  await db.collection('attendance').add({
    uid,
    classId,
    timestamp: admin.firestore.FieldValue.serverTimestamp(),
  });

  // Actualizar racha y total del usuario
  const userRef = db.collection('users').doc(uid);
  await db.runTransaction(async (tx) => {
    const userDoc = await tx.get(userRef);
    if (userDoc.exists) {
      const { totalAttendance = 0, streak = 0 } = userDoc.data();
      tx.update(userRef, { totalAttendance: totalAttendance + 1, streak: streak + 1 });
    }
  });

  return { success: true, message: '¡Asistencia registrada correctamente!' };
});

// ─────────────────────────────────────────────
// FUNCIÓN 2: Generar códigos desde Google Calendar
// Se ejecuta cada 15 minutos. Detecta clases "Flutter Clase..."
// que inician en ~1 hora y genera el código de asistencia.
// ─────────────────────────────────────────────
exports.generateAttendanceCodes = onSchedule(
  { schedule: '*/15 * * * *', timeZone: 'America/Mexico_City' },
  async (event) => {
    const nodemailer = require('nodemailer');

    const gmailUser   = process.env.GMAIL_USER   || '';
    const gmailPass   = process.env.GMAIL_PASS   || '';
    const calendarId  = process.env.CALENDAR_ID  || '';

    // ── Autenticación con Google Calendar vía cuenta de servicio ──
    const auth = new google.auth.GoogleAuth({
      scopes: ['https://www.googleapis.com/auth/calendar.readonly'],
    });
    const authClient = await auth.getClient();
    const calendar = google.calendar({ version: 'v3', auth: authClient });

    // ── Ventana de detección: eventos que inician entre 55 y 75 min ──
    const now = new Date();
    const windowStart = new Date(now.getTime() + 55 * 60 * 1000);
    const windowEnd   = new Date(now.getTime() + 75 * 60 * 1000);

    let events = [];
    try {
      const response = await calendar.events.list({
        calendarId,
        timeMin: windowStart.toISOString(),
        timeMax: windowEnd.toISOString(),
        singleEvents: true,
        orderBy: 'startTime',
        q: 'Flutter Clase',          // Filtrar por nombre
      });
      events = response.data.items || [];
    } catch (err) {
      console.error('Error al leer Google Calendar:', err.message);
      return null;
    }

    if (events.length === 0) {
      console.log('No hay clases "Flutter Clase" próximas en la próxima hora.');
      return null;
    }

    // ── Leer preferencias del instructor (rol B: campo role == "instructor") ──
    const instructorsSnap = await db.collection('instructorSettings')
      .where('role', '==', 'instructor')
      .limit(1)
      .get();

    const instructorData = instructorsSnap.empty ? {} : instructorsSnap.docs[0].data();
    const emailEnabled = instructorData.emailEnabled !== false; // default true
    const pushEnabled  = instructorData.pushEnabled  !== false; // default true
    const fcmToken     = instructorData.fcmToken     || null;

    const mailTransport = nodemailer.createTransport({
      service: 'gmail',
      auth: { user: gmailUser, pass: gmailPass },
    });

    for (const ev of events) {
      const eventId   = ev.id;
      const eventName = ev.summary || 'Flutter Clase';
      const startTime = ev.start.dateTime || ev.start.date;
      const startDate = new Date(startTime);

      // ── Evitar duplicados ──
      const existingDoc = await db.collection('classes').doc(eventId).get();
      if (existingDoc.exists && existingDoc.data().attendanceCode) {
        console.log(`Clase "${eventName}" ya tiene código, saltando.`);
        continue;
      }

      // ── Generar código de 6 dígitos ──
      const code = Math.floor(100000 + Math.random() * 900000).toString();

      // ── Guardar en Firestore ──
      await db.collection('classes').doc(eventId).set({
        eventId,
        name: eventName,
        dateTime: admin.firestore.Timestamp.fromDate(startDate),
        attendanceCode: code,
        codeGeneratedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true });

      console.log(`Código ${code} generado para "${eventName}" (${startTime})`);

      const timeLabel = startDate.toLocaleTimeString('es-MX', {
        hour: '2-digit', minute: '2-digit', timeZone: 'America/Mexico_City',
      });

      // ── Notificación por correo ──
      if (emailEnabled && gmailUser) {
        const mailOptions = {
          from: `"App Asistencia Estudiantes" <${gmailUser}>`,
          to: gmailUser,
          subject: `🔐 Código de Asistencia — ${eventName}`,
          html: `
            <div style="font-family: Arial, sans-serif; max-width: 500px; margin: 0 auto; padding: 24px;">
              <h2 style="color: #1a73e8; margin-bottom: 8px;">Código de Asistencia</h2>
              <p style="color: #555;">Tu clase comienza a las <strong>${timeLabel}</strong></p>
              <div style="background: #f0f4ff; border-radius: 12px; padding: 24px; text-align: center; margin: 24px 0;">
                <p style="margin: 0; font-size: 14px; color: #888;">Código</p>
                <p style="margin: 8px 0 0; font-size: 48px; font-weight: bold; letter-spacing: 10px; color: #1a73e8;">${code}</p>
              </div>
              <p style="color: #888;">${eventName}</p>
              <p style="color: #aaa; font-size: 12px;">Válido durante la clase. No lo compartas antes de que inicie.</p>
            </div>
          `,
        };
        try {
          await mailTransport.sendMail(mailOptions);
          console.log(`Correo enviado para "${eventName}"`);
        } catch (mailErr) {
          console.error('Error al enviar correo:', mailErr.message);
        }
      }

      // ── Notificación push (FCM) ──
      if (pushEnabled && fcmToken) {
        try {
          await admin.messaging().send({
            token: fcmToken,
            notification: {
              title: `🔐 Código listo: ${eventName}`,
              body: `Código: ${code} — Clase a las ${timeLabel}`,
            },
            data: {
              classId: eventId,
              code,
              className: eventName,
            },
          });
          console.log(`Push enviado para "${eventName}"`);
        } catch (pushErr) {
          console.error('Error al enviar push:', pushErr.message);
        }
      }
    }

    return null;
  }
);

// ─────────────────────────────────────────────
// FUNCIÓN 3: Webhook de sincronización con Calendar (placeholder)
// ─────────────────────────────────────────────
exports.syncCalendarWebhook = onRequest(async (req, res) => {
  console.log('Calendar Sync Webhook received notification.');
  res.status(200).send('OK');
});
