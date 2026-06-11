import 'package:flutter/material.dart';

/// Sistema de design centralizado do ToonArchive.
/// Importe este arquivo em todas as telas para garantir consistência visual.
class AppTheme {
  AppTheme._();

  // ── Cores base ─────────────────────────────────────────────
  static const Color roxoPrimario   = Color(0xFF7C3AED);
  static const Color roxoSecundario = Color(0xFF9F67FA);
  static const Color roxoClaro      = Color(0xFFEDE9FE);
  static const Color roxoEscuro     = Color(0xFF4C1D95);
  static const Color accentAmber    = Color(0xFFFBBF24);

  // ── Fundos ─────────────────────────────────────────────────
  static const Color fundoClaro = Color(0xFFF5F3FF);
  static const Color fundoEscuro = Color(0xFF0F0A1E);
  static const Color cardClaro  = Color(0xFFFFFFFF);
  static const Color cardEscuro = Color(0xFF1A1030);
  static const Color surfaceEscuro = Color(0xFF231840);

  // ── Gradientes ─────────────────────────────────────────────
  static LinearGradient gradientePrimario({bool isDark = false}) =>
      LinearGradient(
        colors: isDark
            ? [const Color(0xFF4C1D95), const Color(0xFF6D28D9)]
            : [roxoPrimario, roxoSecundario],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  static LinearGradient gradienteFundo({bool isDark = false}) =>
      LinearGradient(
        colors: isDark
            ? [fundoEscuro, const Color(0xFF160D2E)]
            : [fundoClaro, const Color(0xFFEDE9FE)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      );

  // ── Sombra padrão ──────────────────────────────────────────
  static List<BoxShadow> sombra({bool isDark = false, double opacity = 0.18}) =>
      [
        BoxShadow(
          color: roxoPrimario.withOpacity(opacity),
          blurRadius: 16,
          offset: const Offset(0, 6),
        ),
      ];

  // ── Borda padrão dos cards ─────────────────────────────────
  static BoxDecoration cardDecoration({bool isDark = false}) => BoxDecoration(
        color: isDark ? cardEscuro : cardClaro,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: roxoPrimario.withOpacity(0.14)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.18 : 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      );

  // ── AppBar padrão ──────────────────────────────────────────
  static AppBar appBar({
    required String titulo,
    required bool isDark,
    List<Widget>? actions,
    bool automaticallyImplyLeading = true,
    PreferredSizeWidget? bottom,
  }) =>
      AppBar(
        backgroundColor: isDark ? const Color(0xFF1A1030) : roxoPrimario,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: automaticallyImplyLeading,
        title: Text(
          titulo,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 17,
            letterSpacing: 0.3,
          ),
        ),
        actions: actions,
        bottom: bottom,
      );

  // ── Input decoration padrão ────────────────────────────────
  static InputDecoration inputDecoration({
    required String hint,
    required IconData prefixIcon,
    Widget? suffixIcon,
  }) =>
      InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white60),
        prefixIcon: Icon(prefixIcon, color: Colors.white70),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: Colors.white.withOpacity(0.10),
        contentPadding:
            const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.white, width: 1.5),
        ),
      );

  // ── Botão primário ─────────────────────────────────────────
  static ButtonStyle botaoPrimario() => ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: roxoPrimario,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
      );

  // ── Chip de status ─────────────────────────────────────────
  static Widget chip(String texto, {Color? cor}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: (cor ?? Colors.white).withOpacity(0.18),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          texto,
          style: TextStyle(
            color: cor ?? Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
      );

  // ── ThemeData claro ────────────────────────────────────────
  static ThemeData lightTheme() => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: roxoPrimario,
          brightness: Brightness.light,
        ).copyWith(
          primary: roxoPrimario,
          secondary: roxoSecundario,
          surface: fundoClaro,
        ),
      );

  // ── ThemeData escuro ───────────────────────────────────────
  static ThemeData darkTheme() => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: roxoPrimario,
          brightness: Brightness.dark,
        ).copyWith(
          primary: roxoSecundario,
          secondary: roxoPrimario,
          surface: fundoEscuro,
        ),
      );
}