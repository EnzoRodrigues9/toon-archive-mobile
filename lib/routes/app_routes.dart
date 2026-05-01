import 'package:flutter/material.dart';

// IMPORTS DAS TELAS
import '../screens/login_page.dart';
import '../screens/home_page.dart';
import '../screens/comunidade_page.dart';
import '../screens/detalhe_page.dart';
import '../screens/downloads_page.dart';
import '../screens/leitura_page.dart';
import '../screens/cadastro_page.dart';

class AppRoutes {
  // 🔐 AUTH
  static const login = '/auth/login';

  // 🏠 MAIN
  static const home = '/home';

  // 📚 APP
  static const detalhe = '/detalhe';
  static const leitura = '/leitura';
  static const downloads = '/downloads';
  static const comunidade = '/comunidade';
  static const cadastro = '/cadastro';

  // 📍 MAPA DE ROTAS
  static Map<String, WidgetBuilder> get routes => {
  login: (_) => const LoginPage(),
  cadastro: (_) => const CadastroPage(),
  home: (_) => HomePage(alternarTema: () {}),
  comunidade: (_) => const ComunidadePage(),
  downloads: (_) => const DownloadsPage(),
  detalhe: (_) => const DetalhePage(titulo: ''),
  leitura: (_) => const LeituraPage(
    capitulo: 'Capítulo 1',
    titulo: 'Naruto',
  ),
};
}