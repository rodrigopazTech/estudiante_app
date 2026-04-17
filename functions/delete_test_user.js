const admin = require('firebase-admin');

// Inicialización mínima para script local
if (admin.apps.length === 0) {
  admin.initializeApp({
    projectId: 'students-course-rodrigopaz'
  });
}

const db = admin.firestore();
const auth = admin.auth();
const uid = 'n11pjrc';

async function deleteUser() {
  console.log(`Intentando eliminar usuario: ${uid}`);
  
  try {
    // 1. Eliminar de Auth
    try {
      await auth.deleteUser(uid);
      console.log('✅ Usuario eliminado de Auth.');
    } catch (e) {
      console.log('⚠️ El usuario no existe en Auth o ya fue eliminado.');
    }

    // 2. Eliminar de Firestore
    await db.collection('users').doc(uid).delete();
    console.log('✅ Documento eliminado de Firestore.');
    
    process.exit(0);
  } catch (error) {
    console.error('❌ Error general:', error.message);
    process.exit(1);
  }
}

deleteUser();
