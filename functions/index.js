const { onCall, onRequest, HttpsError } = require('firebase-functions/v2/https');
const { onSchedule } = require('firebase-functions/v2/scheduler');
const { onDocumentCreated } = require('firebase-functions/v2/firestore');
const admin = require('firebase-admin');
const { google } = require('googleapis');

admin.initializeApp();
const db = admin.firestore();

// CONFIGURACIÓN CENTRALIZADA
const DRIVE_FOLDER_ID = '1Wm18WvrcT5p2kmyR7I5ctqGx7c0305xN';
const CALENDAR_ID = '583cf5eb729124a38b36cbd53379afde9b89883be84bb4bd4da8ca7ff83c7ddc@group.calendar.google.com';

// ─────────────────────────────────────────────
// 1. ONBOARDING AUTOMÁTICO (NUEVA)
// ─────────────────────────────────────────────
exports.onStudentSignup = onDocumentCreated('users/{uid}', async (event) => {
  const userData = event.data.data();
  const email = userData.email;

  if (!email) return;

  const auth = new google.auth.GoogleAuth({
    scopes: [
      'https://www.googleapis.com/auth/drive.file',
      'https://www.googleapis.com/auth/calendar.events'
    ],
  });
  const authClient = await auth.getClient();

  try {
    const drive = google.drive({ version: 'v3', auth: authClient });
    await drive.permissions.create({
      fileId: DRIVE_FOLDER_ID,
      requestBody: { role: 'reader', type: 'user', emailAddress: email },
    });
    console.log(`Acceso a Drive concedido a ${email}`);
  } catch (err) { console.error('Error Drive:', err.message); }

  try {
    const calendar = google.calendar({ version: 'v3', auth: authClient });
    const response = await calendar.events.list({ calendarId: CALENDAR_ID, q: 'Flutter Clase' });
    const events = response.data.items || [];
    for (const ev of events) {
      const attendees = ev.attendees || [];
      attendees.push({ email: email });
      await calendar.events.patch({
        calendarId: CALENDAR_ID,
        eventId: ev.id,
        requestBody: { attendees: attendees },
        sendUpdates: 'all',
      });
    }
    console.log(`Usuario ${email} invitado al calendario.`);
  } catch (err) { console.error('Error Calendar:', err.message); }
});

// ─────────────────────────────────────────────
// 2. VALIDAR ASISTENCIA (ORIGINAL)
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

  const existing = await db.collection('attendance')
    .where('uid', '==', uid)
    .where('classId', '==', classId)
    .get();

  if (!existing.empty) {
    return { success: false, message: 'Ya has registrado tu asistencia para esta clase.' };
  }

  await db.collection('attendance').add({
    uid,
    classId,
    timestamp: admin.firestore.FieldValue.serverTimestamp(),
  });

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
// 3. GENERAR CÓDIGOS DE ASISTENCIA (ORIGINAL)
// ─────────────────────────────────────────────
exports.generateAttendanceCodes = onSchedule(
  { schedule: '*/15 * * * *', timeZone: 'America/Mexico_City' },
  async (event) => {
    const nodemailer = require('nodemailer');
    const gmailUser   = process.env.GMAIL_USER   || '';
    const gmailPass   = process.env.GMAIL_PASS   || '';
    const calendarId  = CALENDAR_ID;

    const auth = new google.auth.GoogleAuth({
      scopes: ['https://www.googleapis.com/auth/calendar.readonly'],
    });
    const authClient = await auth.getClient();
    const calendar = google.calendar({ version: 'v3', auth: authClient });

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
        q: 'Flutter Clase',
      });
      events = response.data.items || [];
    } catch (err) {
      console.error('Error al leer Google Calendar:', err.message);
      return null;
    }

    if (events.length === 0) return null;

    const mailTransport = nodemailer.createTransport({
      service: 'gmail',
      auth: { user: gmailUser, pass: gmailPass },
    });

    for (const ev of events) {
      const eventId   = ev.id;
      const code = Math.floor(100000 + Math.random() * 900000).toString();

      await db.collection('classes').doc(eventId).set({
        eventId,
        title: ev.summary,
        dateTime: admin.firestore.Timestamp.fromDate(new Date(ev.start.dateTime || ev.start.date)),
        attendanceCode: code,
        codeGeneratedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true });

      if (gmailUser) {
        await mailTransport.sendMail({
          from: gmailUser, to: gmailUser,
          subject: `🔐 Código de Asistencia — ${ev.summary}`,
          text: `Código: ${code}`,
        });
      }
    }
    return null;
  }
);

// ─────────────────────────────────────────────
// 4. IMPORTAR CLASES PASADAS (ORIGINAL)
// ─────────────────────────────────────────────
exports.importPastClasses = onRequest(async (req, res) => {
  const auth = new google.auth.GoogleAuth({
    scopes: ['https://www.googleapis.com/auth/calendar.readonly'],
  });
  const authClient = await auth.getClient();
  const calendar = google.calendar({ version: 'v3', auth: authClient });

  const courseStart = new Date('2025-01-01T00:00:00Z');
  const response = await calendar.events.list({
    calendarId: CALENDAR_ID,
    timeMin: courseStart.toISOString(),
    timeMax: new Date().toISOString(),
    singleEvents: true,
    q: 'Flutter Clase',
  });

  const events = response.data.items || [];
  for (const ev of events) {
    await db.collection('classes').doc(ev.id).set({
      eventId: ev.id,
      title: ev.summary,
      dateTime: admin.firestore.Timestamp.fromDate(new Date(ev.start.dateTime || ev.start.date)),
      importedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
  }

  return res.json({ imported: events.length });
});

// ─────────────────────────────────────────────
// 5. SINCRONIZAR CLASES Y DRIVE (OPTIMIZADA)
// ─────────────────────────────────────────────
exports.syncUpcomingClasses = onSchedule(
  { schedule: '*/15 * * * *', timeZone: 'America/Mexico_City' },
  async () => {
    const auth = new google.auth.GoogleAuth({
      scopes: [
        'https://www.googleapis.com/auth/calendar.readonly',
        'https://www.googleapis.com/auth/drive.readonly'
      ],
    });
    const authClient = await auth.getClient();

    // Sincronizar Calendario
    const calendar = google.calendar({ version: 'v3', auth: authClient });
    const calRes = await calendar.events.list({ calendarId: CALENDAR_ID, q: 'Flutter Clase' });
    const events = calRes.data.items || [];
    for (const ev of events) {
      await db.collection('classes').doc(ev.id).set({
        title: ev.summary,
        dateTime: admin.firestore.Timestamp.fromDate(new Date(ev.start.dateTime || ev.start.date)),
        meetLink: ev.location,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true });
    }

    // Sincronizar Drive (NUEVO)
    const drive = google.drive({ version: 'v3', auth: authClient });
    const driveRes = await drive.files.list({
      q: `'${DRIVE_FOLDER_ID}' in parents and trashed = false`,
      fields: 'files(id, name, webViewLink, iconLink, mimeType)',
    });
    const files = driveRes.data.files || [];
    for (const file of files) {
      await db.collection('resources').doc(file.id).set({
        name: file.name,
        link: file.webViewLink,
        type: file.mimeType,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true });
    }
  }
);
