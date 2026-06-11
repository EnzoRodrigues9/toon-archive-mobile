import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:toonarchive/app/app_routes.dart';

class SplashPage extends StatefulWidget {
  final VoidCallback alternarTema;
  const SplashPage({super.key, required this.alternarTema});
  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    super.initState();
    _verificar();
  }

  Future<void> _verificar() async {
    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;

    try {
      await Supabase.instance.client.auth.signOut()
          .timeout(const Duration(seconds: 3));
    } catch (_) {}

    if (!mounted) return;
    Navigator.pushReplacementNamed(context, AppRoutes.login);
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF4C1D95),
      body: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          _SplashLogo(),
          SizedBox(height: 20),
          Text('TOON ARCHIVE',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 3)),
          SizedBox(height: 6),
          Text('Sua biblioteca de obras',
              style: TextStyle(color: Colors.white60, fontSize: 13)),
          SizedBox(height: 36),
          SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                  color: Colors.white, strokeWidth: 2.5)),
        ]),
      ),
    );
  }
}

class _SplashLogo extends StatelessWidget {
  const _SplashLogo();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
      ),
      child: const Icon(Icons.menu_book_rounded, size: 56, color: Colors.white),
    );
  }
}