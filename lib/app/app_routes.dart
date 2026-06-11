import 'package:flutter/material.dart';
import 'package:toonarchive/app/modules/home/presentation/pages/home_page.dart';
import 'package:toonarchive/app/modules/auth/presentation/pages/login_page.dart';
import 'package:toonarchive/app/modules/obras/presentation/pages/detalhe_page.dart';
import 'package:toonarchive/app/modules/capitulos/presentation/pages/leitura_page.dart';
import 'package:toonarchive/app/modules/auth/presentation/pages/cadastro_page.dart';
import 'package:toonarchive/app/modules/splash/presentation/pages/splash_page.dart';

class AppRoutes {
  static const splash = '/splash';
  static const login = '/login';
  static const home = '/home';
  static const detalhe = '/detalhe';
  static const leitura = '/leitura';
  static const cadastro = '/cadastro';

  static Route<dynamic>? onGenerateRoute(
    RouteSettings settings,
    VoidCallback alternarTema,
  ) {
    switch (settings.name) {
      case '/splash': 
        return MaterialPageRoute(
          builder: (_) => SplashPage(alternarTema: alternarTema),
        );

      case login:
        return MaterialPageRoute(
          builder: (_) => const LoginPage(),
        );

      case home:
        return MaterialPageRoute(
          builder: (_) => HomePage(
            alternarTema: alternarTema,
          ),
        );

      case cadastro:
        return MaterialPageRoute(
          builder: (_) => const CadastroPage(),
        );

      case detalhe:
        final args = settings.arguments as Map<String, dynamic>;

        return MaterialPageRoute(
          builder: (_) => DetalhePage(
            obraId: args['obraId'],
            titulo: args['titulo'],
          ),
        );

      case leitura:
        final args = settings.arguments as Map<String, dynamic>;

        return MaterialPageRoute(
          builder: (_) => LeituraPage(
            obraId: args['obraId'],
            capituloId: args['capituloId'],
            capitulo: args['capitulo'],
            titulo: args['titulo'],
          ),
        );
    }

    return null;
  }
}