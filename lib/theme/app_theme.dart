import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // TEMA CLARO
  static final ThemeData lightTheme = ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color.fromARGB(255, 63, 81, 181), // Azul principal
      primary: const Color.fromARGB(255, 63, 81, 181),
      secondary: const Color.fromARGB(255, 117, 117, 117), // Gris para acentos
      background: const Color.fromARGB(255, 245, 245, 245),
      surface: Colors.white,
      brightness: Brightness.light,
    ),
    useMaterial3: true,
    scaffoldBackgroundColor: const Color.fromARGB(255, 245, 245, 245),
    textTheme: GoogleFonts.latoTextTheme(),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color.fromARGB(255, 63, 81, 181),
      foregroundColor: Colors.white,
    ),
    cardTheme: CardThemeData(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color.fromARGB(255, 63, 81, 181),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
      ),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      selectedItemColor: Color.fromARGB(255, 63, 81, 181),
    ),
  );

  //TEMA OSCURO
  static final ThemeData darkTheme = ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color.fromARGB(255, 63, 81, 181), // Mismo azul principal
      primary: const Color.fromARGB(255, 121, 134, 203), // Un azul más claro para resaltar
      secondary: const Color.fromARGB(255, 176, 190, 197), // Un gris más claro
      background: const Color.fromARGB(255, 18, 18, 18), // Fondo oscuro estándar
      surface: const Color.fromARGB(255, 30, 30, 30), // Superficie de las tarjetas
      brightness: Brightness.dark,
    ),
    useMaterial3: true,
    scaffoldBackgroundColor: const Color.fromARGB(255, 18, 18, 18),
    textTheme: GoogleFonts.latoTextTheme(
      ThemeData(brightness: Brightness.dark).textTheme,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color.fromARGB(255, 30, 30, 30),
      foregroundColor: Colors.white,
    ),
    cardTheme: CardThemeData(
      color: const Color.fromARGB(255, 30, 30, 30),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color.fromARGB(255, 121, 134, 203),
        foregroundColor: Colors.black,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
      ),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      selectedItemColor: Color.fromARGB(255, 121, 134, 203),
      backgroundColor: Color.fromARGB(255, 30, 30, 30),
    ),
  );
}
