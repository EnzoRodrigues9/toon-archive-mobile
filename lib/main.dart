import 'package:flutter/material.dart';
import 'screens/home_page.dart';

void main() {
  runApp(const ToonArchiveApp());
}

class ToonArchiveApp extends StatefulWidget {
  const ToonArchiveApp({super.key});

  @override
  State<ToonArchiveApp> createState() => _ToonArchiveAppState();
}

class _ToonArchiveAppState extends State<ToonArchiveApp> {
  bool darkMode = false;

  void alternarTema() {
    setState(() {
      darkMode = !darkMode;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Toon Archive',
      themeMode: darkMode ? ThemeMode.dark : ThemeMode.light,

      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF6F2FF),

        colorScheme: const ColorScheme.light(
          primary: Color(0xFF8B5CF6), // 🔥 NOVO ROXO
          secondary: Color(0xFFC4B5FD),
          surface: Colors.white,
        ),

        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF8B5CF6),
          foregroundColor: Colors.white, // 🔥 resolve texto preto
          elevation: 0,
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: const BorderSide(color: Color(0xFFE6D8FF)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFF8F4FF),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFFD8C6FF)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFF5B21B6), width: 1.4),
          ),
        ),
      ),

      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF140F1F),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFB388FF),
          secondary: Color(0xFFD1C4E9),
          surface: Color(0xFF20172C),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF2A1D3D),
          foregroundColor: Colors.white,
          centerTitle: true,
          elevation: 0,
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFF20172C),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: const BorderSide(color: Color(0xFF3A2A55)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF241A35),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFF4A3962)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFFB388FF), width: 1.4),
          ),
        ),
      ),

      home: HomePage(alternarTema: alternarTema),
    );
  }
}
