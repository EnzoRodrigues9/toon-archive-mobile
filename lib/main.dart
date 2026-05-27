import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';
import 'core/database/database_helper.dart';
import 'core/database/supabase_client.dart';
import 'core/sync/sync_service.dart';
import 'routes/app_routes.dart';
import 'screens/splash_page.dart'; 

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await SupabaseClientHelper.init();
  await DatabaseHelper.instance.database;
  SyncService.instance.start();
  runApp(const ToonArchiveApp());
}

class ToonArchiveApp extends StatefulWidget {
  const ToonArchiveApp({super.key});
  @override
  State<ToonArchiveApp> createState() => _ToonArchiveAppState();
}

class _ToonArchiveAppState extends State<ToonArchiveApp> {
  bool darkMode = false;

  void alternarTema() => setState(() => darkMode = !darkMode);

  @override
  void dispose() {
    SyncService.instance.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Toon Archive',
      initialRoute: '/splash',
      onGenerateRoute: (s) => AppRoutes.onGenerateRoute(s, alternarTema),
      themeMode: darkMode ? ThemeMode.dark : ThemeMode.light,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF7C3AED)).copyWith(
          primary: const Color(0xFF7C3AED),
          secondary: const Color(0xFF9F67FA),
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF7C3AED),
          brightness: Brightness.dark,
        ).copyWith(
          primary: const Color(0xFF9F67FA),
          secondary: const Color(0xFF7C3AED),
        ),
      ),
    );
  }
}