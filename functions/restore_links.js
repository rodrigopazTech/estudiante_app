const admin = require('firebase-admin');

if (admin.apps.length === 0) {
  admin.initializeApp({
    projectId: 'students-course-rodrigopaz'
  });
}

const db = admin.firestore();

// MAPA DE LINKS (Extraídos de la consulta de Drive anterior)
const driveLinks = {
  "Hora_1": "https://drive.google.com/drive/folders/1iMtpF6Ssx56N8tRqGABkdsmGh3qJeY98",
  "Hora_2": "https://drive.google.com/drive/folders/1vYfX_B3S4xfP4eyY65EngMwwpyRMMIOJ",
  "Hora_3": "https://drive.google.com/drive/folders/1lwhRpwsaMXkl9XqID9rzq0YFjTsyaY8Z",
  "Hora_4": "https://drive.google.com/drive/folders/1tEtcVn4V-cddYYMdKl5j3aI4ADO8Der5",
  "Hora_5": "https://drive.google.com/drive/folders/10kuqAsVNe11dT9WoBLge-NYKDzwAhlmA",
  "Hora_6": "https://drive.google.com/drive/folders/1lUTHDvmTuiMyCsUim1SjNfsEFTf3n5py",
  "Hora_7": "https://drive.google.com/drive/folders/1vzaSrA_d-5UONMqkhN6Zz6b1uy-yDV9v",
  "Hora_8": "https://drive.google.com/drive/folders/1eJDM0WOWLvuIOxULITT1LL4NDQc6-EhQ",
  "Hora_9": "https://drive.google.com/drive/folders/1OfI1zbbiQmMegqB0jASKr0JP-UHm4jVg",
  "Hora_10": "https://drive.google.com/drive/folders/1zbYh2TrwM7r1WdZZjsqTXAPcnKI1YUdS",
  "Hora_11": "https://drive.google.com/drive/folders/1LzcehG3Srg2SIUuTqGCja0fLI7fzJC9I",
  "Hora_12": "https://drive.google.com/drive/folders/14JOA5qLRcA6pZWYzyJihn9pKXNHjCZgo",
  "Hora_13": "https://drive.google.com/drive/folders/1sfSu83OVpBkXg6jsCenglP7quhBc0dh1",
  "Hora_14": "https://drive.google.com/drive/folders/17WtkrBjiFMeBdqqbOA103g1Nc_i5Nny1",
  "Hora_15": "https://drive.google.com/drive/folders/10agjw1TH3ze-c6_bWHZWZzOf1YEncIcb",
  "Hora_16": "https://drive.google.com/drive/folders/1Mz53j857l5jxeaPmZBjigA46-MU_wOmJ"
};

async function restoreLinks() {
  console.log("Iniciando restauración de links en Firestore...");
  const classesRef = db.collection('classes');
  const snapshot = await classesRef.get();

  if (snapshot.empty) {
    console.log("No se encontraron clases en la colección 'classes'.");
    return;
  }

  const batch = db.batch();
  let count = 0;

  snapshot.forEach(doc => {
    const data = doc.data();
    const title = data.title || ""; // Ej: "Flutter Clase 01: Intro a Dart"
    
    // Extraemos el número de la clase (01, 02, etc.)
    const match = title.match(/Clase (\d+)/);
    if (match) {
      const horaNum = parseInt(match[1]);
      const key = `Hora_${horaNum}`;
      const link = driveLinks[key];

      if (link) {
        batch.update(doc.ref, {
          driveLink: link,
          docLink: link, // Por ahora usamos el mismo link de la carpeta
          updatedAt: admin.firestore.FieldValue.serverTimestamp()
        });
        console.log(`✅ Mapeado: "${title}" -> ${key}`);
        count++;
      }
    }
  });

  if (count > 0) {
    await batch.commit();
    console.log(`🚀 Éxito: Se actualizaron ${count} clases con sus links de Drive.`);
  } else {
    console.log("⚠️ No se pudo mapear ninguna clase. Verifica los títulos en Firestore.");
  }
}

restoreLinks().catch(err => console.error("Error:", err));
