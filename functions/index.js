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
// 1. ONBOARDING AUTOMÁTICO (REACTIVA)
// ─────────────────────────────────────────────
exports.onStudentSignup = onDocumentCreated('users/{uid}', async (event) => {
  const userData = event.data.data();
  const email = userData.email;

  if (!email) return;
  console.log(`Iniciando onboarding automático para: ${email}`);

  const auth = new google.auth.GoogleAuth({
    scopes: [
      'https://www.googleapis.com/auth/drive',    // Compartir carpeta de Drive
      'https://www.googleapis.com/auth/calendar', // ✅ Scope completo: permite acl.insert()
    ],
  });
  const authClient = await auth.getClient();

  // A. Otorgar Acceso a Drive
  try {
    const drive = google.drive({ version: 'v3', auth: authClient });
    await drive.permissions.create({
      fileId: DRIVE_FOLDER_ID,
      requestBody: { role: 'reader', type: 'user', emailAddress: email },
    });
    console.log(`Acceso a Drive concedido a ${email}`);
  } catch (err) { console.error('Error Drive:', err.message); }

  // B. Compartir el Calendario completo con el alumno
  // calendar.acl.insert() funciona con cuentas @gmail.com personales
  // (calendar.events.patch con attendees requiere Google Workspace + DWD)
  try {
    const calendar = google.calendar({ version: 'v3', auth: authClient });
    await calendar.acl.insert({
      calendarId: CALENDAR_ID,
      requestBody: {
        role: 'reader',
        scope: { type: 'user', value: email },
      },
    });
    console.log(`📅 Calendario compartido con ${email}`);
  } catch (err) { console.error('❌ Error Calendar ACL:', err.message); }
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

    const instructorsSnap = await db.collection('instructorSettings')
      .where('role', '==', 'instructor')
      .limit(1)
      .get();

    const instructorData = instructorsSnap.empty ? {} : instructorsSnap.docs[0].data();
    const emailEnabled = instructorData.emailEnabled !== false;
    const pushEnabled  = instructorData.pushEnabled  !== false;
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

      const existingDoc = await db.collection('classes').doc(eventId).get();
      if (existingDoc.exists && existingDoc.data().attendanceCode) continue;

      const code = Math.floor(100000 + Math.random() * 900000).toString();

      await db.collection('classes').doc(eventId).set({
        eventId,
        title: eventName,
        dateTime: admin.firestore.Timestamp.fromDate(startDate),
        attendanceCode: code,
        codeGeneratedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true });

      const timeLabel = startDate.toLocaleTimeString('es-MX', {
        hour: '2-digit', minute: '2-digit', timeZone: 'America/Mexico_City',
      });

      if (emailEnabled && gmailUser) {
        try {
          await mailTransport.sendMail({
            from: `"App Asistencia" <${gmailUser}>`,
            to: gmailUser,
            subject: `🔐 Código de Asistencia — ${eventName}`,
            html: `
              <div style="font-family: Arial, sans-serif; max-width: 520px; margin: 0 auto; padding: 24px; background: #f9f9f9; border-radius: 12px;">
                <h2 style="color: #1a73e8; margin-bottom: 4px;">Código de Asistencia</h2>
                <p style="color: #555; margin-top: 0;">Tu clase comienza a las <strong>${timeLabel}</strong></p>
                <div style="background: #e8f0fe; border-radius: 12px; padding: 28px; text-align: center; margin: 24px 0;">
                  <p style="margin: 0; font-size: 13px; color: #888; text-transform: uppercase; letter-spacing: 1px;">Código</p>
                  <p style="margin: 12px 0 0; font-size: 52px; font-weight: 800; letter-spacing: 12px; color: #1a73e8;">${code}</p>
                </div>
                <p style="color: #444; font-weight: 600;">${eventName}</p>
                <p style="color: #aaa; font-size: 12px;">Válido durante la clase. No lo compartas antes de que inicie.</p>
              </div>
            `,
          });
          console.log(`✅ Correo de código enviado al instructor para "${eventName}"`);
        } catch (e) {
          console.error(`❌ Error al enviar correo para "${eventName}":`, e.message);
        }
      }

      if (pushEnabled && fcmToken) {
        try {
          await admin.messaging().send({
            token: fcmToken,
            notification: {
              title: `🔐 Código listo: ${eventName}`,
              body: `Código: ${code} — Clase a las ${timeLabel}`,
            },
            data: { classId: eventId, code, className: eventName },
          });
          console.log(`🔔 Push enviado al instructor para "${eventName}"`);
        } catch (e) {
          console.error(`❌ Error al enviar push para "${eventName}":`, e.message);
        }
      }
    }
    return null;
  }
);

// ─────────────────────────────────────────────
// 4. IMPORTAR CLASES PASADAS (RESTAURADA SEGURIDAD)
// ─────────────────────────────────────────────
exports.importPastClasses = onRequest(async (req, res) => {
  // RESTAURADO: Protección básica
  const secret = process.env.IMPORT_SECRET || 'flutter-import-2025';
  if (req.query.secret !== secret) {
    return res.status(403).json({ error: 'Acceso denegado.' });
  }

  const calendarId = CALENDAR_ID;
  const auth = new google.auth.GoogleAuth({
    scopes: ['https://www.googleapis.com/auth/calendar.readonly'],
  });
  const authClient = await auth.getClient();
  const calendar = google.calendar({ version: 'v3', auth: authClient });

  const courseStart = new Date('2025-01-01T00:00:00Z');
  try {
    // Paginación: máx 250 eventos por página, iterar hasta obtener todos
    let allEvents = [];
    let pageToken = undefined;
    do {
      const response = await calendar.events.list({
        calendarId,
        timeMin: courseStart.toISOString(),
        timeMax: new Date().toISOString(),
        singleEvents: true,
        orderBy: 'startTime',
        q: 'Flutter Clase',
        maxResults: 250,
        pageToken,
      });
      allEvents = allEvents.concat(response.data.items || []);
      pageToken = response.data.nextPageToken;
    } while (pageToken);

    let imported = 0;
    let skipped = 0;
    for (const ev of allEvents) {
      const ref = db.collection('classes').doc(ev.id);
      const snap = await ref.get();
      if (snap.exists) { skipped++; continue; }

      await ref.set({
        eventId: ev.id,
        title: ev.summary,
        dateTime: admin.firestore.Timestamp.fromDate(new Date(ev.start.dateTime || ev.start.date)),
        recordingLink: null,
        driveLink: null,
        docLink: null,
        importedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      console.log(`✅ Importada: "${ev.summary}"`);
      imported++;
    }
    return res.json({
      imported,
      skipped,
      total: allEvents.length,
      message: `✅ Importación completa. ${imported} nuevas, ${skipped} ya existían.`,
    });
  } catch (err) {
    console.error('❌ importPastClasses error:', err.message);
    return res.status(500).json({ error: err.message });
  }
});

// ─────────────────────────────────────────────
// 5. SINCRONIZAR CLASES Y DRIVE (FUSIONADA COMPLETA)
// ─────────────────────────────────────────────
exports.syncUpcomingClasses = onSchedule(
  { schedule: '*/15 * * * *', timeZone: 'America/Mexico_City' },
  async () => {
    const calendarId = CALENDAR_ID;

    // ── Autenticación con scopes para Calendar y Drive ──
    const auth = new google.auth.GoogleAuth({
      scopes: [
        'https://www.googleapis.com/auth/calendar.readonly',
        'https://www.googleapis.com/auth/drive' // ✅ CORREGIDO: Scope para leer archivos ajenos
      ],
    });
    const authClient = await auth.getClient();

    // A. Sincronizar Calendario (Con detección de reprogramación y FCM)
    try {
      const calendar = google.calendar({ version: 'v3', auth: authClient });
      const now = new Date();
      const future = new Date(now.getTime() + 30 * 24 * 60 * 60 * 1000);

      const response = await calendar.events.list({
        calendarId,
        timeMin: now.toISOString(),
        timeMax: future.toISOString(),
        singleEvents: true,
        orderBy: 'startTime',
        q: 'Flutter Clase',
      });

      const events = response.data.items || [];
      for (const ev of events) {
        const ref = db.collection('classes').doc(ev.id);
        const snap = await ref.get();
        const newDate = new Date(ev.start.dateTime || ev.start.date);

        if (!snap.exists) {
          await ref.set({
            eventId: ev.id,
            title: ev.summary,
            dateTime: admin.firestore.Timestamp.fromDate(newDate),
            meetLink: ev.location,
            importedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
          continue;
        }

        // DETECTAR REPROGRAMACIÓN (Lógica original restaurada)
        const existing = snap.data();
        const storedDate = existing.dateTime ? existing.dateTime.toDate() : null;
        if (storedDate && Math.abs(storedDate - newDate) > 60 * 1000) {
          await ref.update({
            title: ev.summary,
            dateTime: admin.firestore.Timestamp.fromDate(newDate),
            rescheduledAt: admin.firestore.FieldValue.serverTimestamp(),
          });

          // Notificar a alumnos con FCM
          const usersSnap = await db.collection('users').where('fcmToken', '!=', null).get();
          const messages = [];
          usersSnap.forEach(doc => {
            const token = doc.data().fcmToken;
            if (token) {
              messages.push({
                token,
                notification: {
                  title: '📅 Clase reprogramada',
                  body: `"${ev.summary}" cambió al ${newDate.toLocaleString('es-MX')}`,
                },
                data: { classId: ev.id, type: 'reschedule' },
              });
            }
          });
          if (messages.length > 0) {
            try {
              const result = await admin.messaging().sendEach(messages);
              console.log(`🔔 Notificaciones de reprogramación: ${result.successCount}/${messages.length} enviadas`);
            } catch (fcmErr) {
              console.error('❌ Error al enviar notificaciones de reprogramación:', fcmErr.message);
            }
          }
        } else if (existing.title !== ev.summary) {
          await ref.update({ title: ev.summary });
        }
      }
    } catch (err) { console.error('❌ Error sincronizando calendario:', err.message); }

    // B. Sincronizar Archivos de Drive (NUEVO)
    try {
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
          icon: file.iconLink,
          type: file.mimeType,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        }, { merge: true });
      }
      console.log(`Sincronizados ${files.length} archivos de Drive.`);
    } catch (err) { console.error('Error sincronizando Drive:', err.message); }

    return null;
  }
);
