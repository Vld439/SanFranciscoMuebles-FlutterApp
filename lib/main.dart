import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'providers/cart_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/auth_wrapper.dart';
import 'services/auth_service.dart';
import 'services/firestore_service.dart';
import 'services/storage_service.dart';
import 'theme/app_theme.dart';

// Punto de entrada de la aplicación
// Inicializa Firebase y carga las preferencias del usuario
Future<void> main() async {
  // Necesario antes de usar cualquier plugin de Flutter
  WidgetsFlutterBinding.ensureInitialized();

  // Conecta la app con Firebase (Firestore, Auth, Storage)
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Cargamos el tema guardado del usuario (claro/oscuro)
  final prefs = await SharedPreferences.getInstance();
  final String? themeString = prefs.getString('theme_mode');

  ThemeMode initialThemeMode;
  if (themeString == 'dark') {
    initialThemeMode = ThemeMode.dark;
  } else {
    initialThemeMode = ThemeMode.light; // Por defecto modo claro
  }

  // Iniciamos la aplicación con el tema guardado
  runApp(MyApp(initialThemeMode: initialThemeMode));
}

// Widget raíz de la aplicación
// Configura los providers y el tema general
class MyApp extends StatelessWidget {
  final ThemeMode initialThemeMode; // Tema inicial cargado de preferencias

  const MyApp({
    super.key,
    required this.initialThemeMode,
  });

  @override
  Widget build(BuildContext context) {
    // MultiProvider hace que los servicios estén disponibles en toda la app
    return MultiProvider(
      providers: [
        // Servicios singleton: se crean una vez y se comparten
        Provider<AuthService>(create: (_) => AuthService()),
        Provider<FirestoreService>(create: (_) => FirestoreService()),
        Provider<StorageService>(create: (_) => StorageService()),

        // Providers que notifican cambios a la UI cuando su estado cambia
        ChangeNotifierProvider(
          create: (_) => ThemeProvider(initialThemeMode),
        ),
        ChangeNotifierProvider(
          create: (_) => CartProvider(),
        ),
      ],
      // Consumer reconstruye la app cuando cambia el tema
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            title: 'San Francisco Muebles',
            theme: AppTheme.lightTheme, // Definición del tema claro
            darkTheme: AppTheme.darkTheme, // Definición del tema oscuro
            themeMode: themeProvider.themeMode, // Tema activo actual
            home: const AuthWrapper(), // Decide mostrar login o home según auth
            debugShowCheckedModeBanner: false,
          );
        },
      ),
    );
  }
}
