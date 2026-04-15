const functions = require('firebase-functions');
const admin = require('firebase-admin');
const { google } = require('googleapis');

admin.initializeApp();
const db = admin.firestore();

/**
 * Validates the attendance code sent by the student.
 * This is a HTTPS Callable function.
 */
exports.validateAttendance = functions.https.onCall(async (data, context) => {
  // Check if user is authenticated
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be logged in.');
  }

  const { classId, code } = data;
  const uid = context.auth.uid;

  if (!classId || !code) {
    throw new functions.https.HttpsError('invalid-argument', 'Missing classId or code.');
  }

  const classRef = db.collection('classes').doc(classId);
  const classDoc = await classRef.get();

  if (!classDoc.exists) {
    throw new functions.https.HttpsError('not-found', 'Class not found.');
  }

  const classData = classDoc.data();
  const serverCode = classData.attendanceCode;
  const classTime = classData.dateTime.toDate();
  
  // Check if current time is within 3 hours of the class start time
  const now = new Date();
  const diffHours = Math.abs(now - classTime) / 36e5;
  
  if (diffHours > 3) {
    return { success: false, message: 'La validación solo está disponible durante el horario de clase.' };
  }

  if (serverCode === code) {
    // Check if user already registered attendance
    const attendanceRef = db.collection('attendance').where('uid', '==', uid).where('classId', '==', classId);
    const attendanceSnapshot = await attendanceRef.get();

    if (!attendanceSnapshot.empty) {
      return { success: false, message: 'Ya has registrado tu asistencia para esta clase.' };
    }

    // Record attendance
    await db.collection('attendance').add({
      uid: uid,
      classId: classId,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Update user streak and total
    const userRef = db.collection('users').doc(uid);
    await db.runTransaction(async (transaction) => {
      const userDoc = await transaction.get(userRef);
      if (userDoc.exists) {
        const userData = userDoc.data();
        const newTotal = (userData.totalAttendance || 0) + 1;
        const newStreak = (userData.streak || 0) + 1; // Simplified streak logic
        transaction.update(userRef, {
          totalAttendance: newTotal,
          streak: newStreak,
        });
      }
    });

    return { success: true, message: '¡Asistencia registrada correctamente!' };
  } else {
    return { success: false, message: 'Código de asistencia incorrecto.' };
  }
});

/**
 * Scheduled function to generate attendance codes for classes happening today.
 * Runs every day at midnight.
 */
exports.generateAttendanceCodes = functions.pubsub.schedule('0 0 * * *').onRun(async (context) => {
  const today = new Date();
  today.setHours(0, 0, 0, 0);
  const tomorrow = new Date(today);
  tomorrow.setDate(tomorrow.getDate() + 1);

  const classesSnapshot = await db.collection('classes')
    .where('dateTime', '>=', today)
    .where('dateTime', '<', tomorrow)
    .get();

  const batch = db.batch();
  classesSnapshot.forEach(doc => {
    const code = Math.floor(100000 + Math.random() * 900000).toString(); // 6 digit code
    batch.update(doc.ref, { attendanceCode: code });
  });

  await batch.commit();
  console.log(`Generated codes for ${classesSnapshot.size} classes.`);
  return null;
});

/**
 * Template for Google Calendar Sync via Webhook.
 * In a real scenario, you'd register this URL in Google Cloud Console.
 */
exports.syncCalendarWebhook = functions.https.onRequest(async (req, res) => {
  // 1. Verify Google signature (for security)
  // 2. Fetch changes from Google Calendar API
  // 3. Update Firestore 'classes' collection
  // 4. Send FCM notifications if an event was moved/changed
  
  // This is a placeholder for the logic mentioned in the plan
  console.log('Calendar Sync Webhook received notification.');
  res.status(200).send('OK');
});
