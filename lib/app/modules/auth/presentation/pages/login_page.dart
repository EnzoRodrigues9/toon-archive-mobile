import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:toonarchive/app/core/services/auth_service.dart';
import 'package:toonarchive/app/app_routes.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool _isLoading = false;
  bool _senhaVisivel = false;
  bool _online = true;

  // Campo unificado — aceita email ou nome de usuário
  final _identificadorController = TextEditingController();
  final _senhaController = TextEditingController();
  final _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _verificarConexao();
  }

  @override
  void dispose() {
    _identificadorController.dispose();
    _senhaController.dispose();
    super.dispose();
  }

  Future<void> _verificarConexao() async {
    final result = await Connectivity().checkConnectivity();
    if (!mounted) return;
    setState(
        () => _online = result.any((r) => r != ConnectivityResult.none));
  }

  Future<void> _loginComEmail() async {
    final identificador = _identificadorController.text.trim();
    final senha = _senhaController.text.trim();
    if (identificador.isEmpty || senha.isEmpty) {
      _erro('Preencha o email/usuário e a senha.');
      return;
    }
    setState(() => _isLoading = true);
    final usuario = await _authService.loginComEmail(
      email: identificador,
      senha: senha,
      onErro: _erro,
    );
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (usuario != null) {
      Navigator.pushReplacementNamed(context, AppRoutes.home);
    }
  }

  Future<void> _loginComGoogle() async {
    setState(() => _isLoading = true);
    final usuario = await _authService.signInWithGoogle(onErro: _erro);
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (usuario != null) {
      Navigator.pushReplacementNamed(context, AppRoutes.home);
    }
  }

  void _erro(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(msg),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF4C1D95), Color(0xFF7C3AED), Color(0xFF9F67FA)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                  minHeight: MediaQuery.of(context).size.height -
                      MediaQuery.of(context).padding.top),
              child: IntrinsicHeight(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 32),

                    // Logo
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.12),
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: Colors.white.withOpacity(0.25), width: 2),
                      ),
                      child: const Icon(Icons.menu_book_rounded,
                          size: 52, color: Colors.white),
                    ),
                    const SizedBox(height: 20),
                    const Text('TOON ARCHIVE',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 3)),
                    const SizedBox(height: 6),
                    Text('Sua biblioteca de obras',
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 14)),
                    const SizedBox(height: 12),

                    // Banner offline
                    if (!_online) _bannerOffline(),

                    const SizedBox(height: 28),

                    // Campo email ou nome de usuário
                    _campo(
                      controller: _identificadorController,
                      hint: 'Email ou nome de usuário',
                      icon: Icons.person_outline_rounded,
                      tipo: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 14),

                    // Senha
                    _campo(
                      controller: _senhaController,
                      hint: 'Senha',
                      icon: Icons.lock_outline_rounded,
                      obscure: !_senhaVisivel,
                      onSubmit: (_) => _loginComEmail(),
                      sufixo: IconButton(
                        icon: Icon(
                            _senhaVisivel
                                ? Icons.visibility_off
                                : Icons.visibility,
                            color: Colors.white60),
                        onPressed: () =>
                            setState(() => _senhaVisivel = !_senhaVisivel),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Botão entrar
                    _botao(texto: 'Entrar', onTap: _loginComEmail),
                    const SizedBox(height: 12),

                    TextButton(
                      onPressed: _isLoading
                          ? null
                          : () => Navigator.pushNamed(
                              context, AppRoutes.cadastro),
                      child: const Text('Criar conta',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600)),
                    ),

                    // Divisor e Google — só exibe se online
                    if (_online) ...[
                      const SizedBox(height: 8),
                      Row(children: [
                        Expanded(
                            child: Divider(
                                color: Colors.white.withOpacity(0.3))),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text('OU',
                              style: TextStyle(
                                  color: Colors.white.withOpacity(0.6),
                                  fontSize: 12)),
                        ),
                        Expanded(
                            child: Divider(
                                color: Colors.white.withOpacity(0.3))),
                      ]),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _isLoading ? null : _loginComGoogle,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: BorderSide(
                                color: Colors.white.withOpacity(0.4)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                          ),
                          icon: const Icon(Icons.g_mobiledata_rounded,
                              size: 24),
                          label: const Text('Entrar com Google',
                              style:
                                  TextStyle(fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _bannerOffline() => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.25)),
        ),
        child: Row(children: [
          const Icon(Icons.wifi_off_rounded, color: Colors.white70, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Sem conexão. Use seu email/usuário e senha para entrar offline.',
              style: TextStyle(
                  color: Colors.white.withOpacity(0.85), fontSize: 12),
            ),
          ),
        ]),
      );

  Widget _campo({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscure = false,
    TextInputType tipo = TextInputType.text,
    Widget? sufixo,
    void Function(String)? onSubmit,
  }) =>
      TextField(
        controller: controller,
        obscureText: obscure,
        keyboardType: tipo,
        style: const TextStyle(color: Colors.white),
        onSubmitted: onSubmit,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.white.withOpacity(0.55)),
          prefixIcon: Icon(icon, color: Colors.white70, size: 20),
          suffixIcon: sufixo,
          filled: true,
          fillColor: Colors.white.withOpacity(0.10),
          contentPadding:
              const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide:
                  BorderSide(color: Colors.white.withOpacity(0.2))),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide:
                  BorderSide(color: Colors.white.withOpacity(0.2))),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide:
                  const BorderSide(color: Colors.white, width: 1.5)),
        ),
      );

  Widget _botao(
          {required String texto, required VoidCallback onTap}) =>
      SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _isLoading ? null : onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: const Color(0xFF7C3AED),
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
          ),
          child: _isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Color(0xFF7C3AED)))
              : Text(texto,
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 16)),
        ),
      );
}