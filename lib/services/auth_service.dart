import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Servicio de autenticación que maneja login con Google
// y gestión de usuarios en Firestore
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // Stream que notifica cuando el usuario inicia o cierra sesión
  // Úsalo en la app para redirigir a login o home automáticamente
  Stream<User?> get user => _auth.authStateChanges();

  // Obtiene el usuario actual de forma síncrona
  // Útil cuando necesitas el usuario inmediatamente sin esperar el stream
  User? get currentUser => _auth.currentUser;

  // Inicia sesión con Google
  // Muestra el selector de cuentas y crea el perfil si es primera vez
  Future<User?> signInWithGoogle() async {
    try {
      // Iniciamos el flujo de Google Sign In
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        // El usuario canceló el login
        return null;
      }

      // Obtenemos las credenciales de autenticación
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Autenticamos con Firebase
      final UserCredential userCredential = await _auth.signInWithCredential(
        credential,
      );
      final User? user = userCredential.user;

      if (user != null) {
        // Creamos o actualizamos el perfil del usuario en Firestore
        await updateUserData(user);
      }
      return user;
    } catch (e) {
      print('Error durante el inicio de sesión con Google: $e');
      return null;
    }
  }

  // Crea o actualiza el perfil del usuario en Firestore
  // Los nuevos usuarios reciben rol 'client' por defecto
  Future<void> updateUserData(User user) async {
    final userRef = _db.collection('users').doc(user.uid);
    final snapshot = await userRef.get();

    if (!snapshot.exists) {
      // Usuario nuevo, creamos su perfil completo
      await userRef.set({
        'uid': user.uid,
        'email': user.email,
        'photoURL': user.photoURL,
        'displayName': user.displayName,
        'lastSignIn': FieldValue.serverTimestamp(),
        'role': 'client', // Por defecto todos son clientes
      });
    } else {
      // Usuario existente, solo actualizamos la última conexión
      await userRef.update({'lastSignIn': FieldValue.serverTimestamp()});
    }
  }

  // Cierra sesión y limpia la caché de Google
  // Esto asegura que la próxima vez muestre el selector de cuentas
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      await _googleSignIn.disconnect();
    } catch (e) {
      print('Error during Google Sign-Out/Disconnect, continuing logout: $e');
    } finally {
      // Este es el paso crucial que actualiza la UI de la app
      await _auth.signOut();
    }
  }
}
