import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider with ChangeNotifier {
  ThemeMode _themeMode; // Ya no se inicializa

  //Constructor que acepta el modo inicial (cargado en main.dart)
  ThemeProvider(this._themeMode);

  ThemeMode get themeMode => _themeMode; // Getter para el modo de tema actual

  Future<void> loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final String? themeString = prefs.getString('theme_mode');
    if (themeString != null) {
      _themeMode = themeString == 'light' ? ThemeMode.light : ThemeMode.dark;
    }
    notifyListeners();
  } //método para cargar el tema guardado

  // Convierte 'toggleTheme' en 'async' para poder guardar
  void toggleTheme() async {
    // Lógica para cambiar el tema
    _themeMode =
        _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;

    notifyListeners(); // Notifica a los widgets

    // Guarda la nueva preferencia en el dispositivo
    try {
      final prefs = await SharedPreferences.getInstance();
      // Guardamos 'light' o 'dark' como un string
      final String themeString =
          _themeMode == ThemeMode.light ? 'light' : 'dark';
      await prefs.setString('theme_mode', themeString);
    } catch (e) {
      print("Error al guardar el tema: $e");
    }
  }
}
