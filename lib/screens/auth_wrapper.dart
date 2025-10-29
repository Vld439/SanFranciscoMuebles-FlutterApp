import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../models/firestore_models.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import 'login_screen.dart';
import 'home_screen.dart';
import 'buyer_home_screen.dart';

// Wrapper que redirige al usuario según su estado de autenticación y rol
// - No autenticado > LoginScreen
// - Autenticado como admin > HomeScreen (pantalla de administrador)
// - Autenticado como client > BuyerHomeScreen (pantalla de cliente)
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    final firestoreService = context.read<FirestoreService>();

    return StreamBuilder<User?>(
      stream: authService.user,
      builder: (context, authSnapshot) {
        // Esperando datos de autenticación
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (authSnapshot.hasData && authSnapshot.data != null) {
          // Usuario autenticado, ahora verificamos su rol en Firestore
          return StreamBuilder<AppUser?>(
            stream: firestoreService.getUserStream(authSnapshot.data!.uid),
            builder: (context, userSnapshot) {
              if (userSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }

              if (userSnapshot.hasData && userSnapshot.data != null) {
                // Redirigimos según el rol del usuario
                if (userSnapshot.data!.role == 'admin') {
                  return const HomeScreen(); // Pantalla para administradores
                } else {
                  return const BuyerHomeScreen(); // Pantalla para clientes
                }
              }

              // Si no hay datos del usuario, por defecto va a la pantalla de cliente
              return const BuyerHomeScreen();
            },
          );
        }

        // Usuario no autenticado, mostramos el login
        return const LoginScreen();
      },
    );
  }
}
