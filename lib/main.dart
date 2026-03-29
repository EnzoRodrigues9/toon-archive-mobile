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

      theme: ThemeData(
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),

      darkTheme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
      ),

      themeMode: darkMode ? ThemeMode.dark : ThemeMode.light,

      home: HomePage(alternarTema: alternarTema),
    );
  }
}
