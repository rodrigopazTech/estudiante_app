// Firebase Cloud Messaging Service Worker
// Requerido para recibir notificaciones push en Flutter Web

importScripts("https://www.gstatic.com/firebasejs/10.7.0/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/10.7.0/firebase-messaging-compat.js");

firebase.initializeApp({
  apiKey: "AIzaSyB813rMjjJAKd5z1yWG34W55X9g85_Cu-I",
  authDomain: "students-course-rodrigopaz.firebaseapp.com",
  projectId: "students-course-rodrigopaz",
  storageBucket: "students-course-rodrigopaz.firebasestorage.app",
  messagingSenderId: "60417216583",
  appId: "1:60417216583:web:493c129d71dcdd4b3be162",
});

const messaging = firebase.messaging();

// Manejar notificaciones cuando la app está en segundo plano
messaging.onBackgroundMessage((payload) => {
  console.log("[SW] Notificación en background:", payload);
  const { title, body } = payload.notification || {};
  self.registration.showNotification(title || "Estudiante App", {
    body: body || "",
    icon: "/icons/Icon-192.png",
  });
});
