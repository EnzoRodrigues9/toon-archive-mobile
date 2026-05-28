import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../services/auth_service.dart';
import '../routes/app_routes.dart';

class CadastroPage extends StatefulWidget {
  const CadastroPage({super.key});
  @override
  State<CadastroPage> createState() => _CadastroPageState();
}

class _CadastroPageState extends State<CadastroPage> {
  bool _isLoading = false;
  bool _senhaVisivel = false;
  bool _confirmarVisivel = false;
  bool _online = true;

  final _nomeController = TextEditingController();
  final _emailController = TextEditingController();
  final _senhaController = TextEditingController();
  final _confirmarController = TextEditingController();
  final _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _verificarConexao();
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _emailController.dispose();
    _senhaController.dispose();
    _confirmarController.dispose();
    super.dispose();
  }

  Future<void> _verificarConexao() async {
    final result = await Connectivity().checkConnectivity();
    if (!mounted) return;
    setState(
        () => _online = result.any((r) => r != ConnectivityResult.none));
  }

  Future<void> _cadastrar() async {
    final nome = _nomeController.text.trim();
    final email = _emailController.text.trim();
    final senha = _senhaController.text.trim();
    final confirmar = _confirmarController.text.trim();

    if (nome.isEmpty || email.isEmpty || senha.isEmpty || confirmar.isEmpty) {
      _erro('Preencha todos os campos.');
      return;
    }
    if (nome.length < 2) {
      _erro('Nome muito curto.');
      return;
    }
    if (!email.contains('@')) {
      _erro('Email inválido.');
      return;
    }
    if (senha.length < 6) {
      _erro('Senha com mínimo 6 caracteres.');
      return;
    }
    if (senha != confirmar) {
      _erro('Senhas não coincidem.');
      return;
    }

    setState(() => _isLoading = true);
    final usuario = await _authService.cadastrar(
      nome: nome,
      email: email,
      senha: senha,
      onErro: _erro,
    );
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (usuario != null) {
      final isOffline = !_online;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(isOffline
            ? 'Conta criada offline! Será sincronizada quando conectar.'
            : 'Conta criada com sucesso!'),
        backgroundColor: Colors.green,
      ));
      await Future.delayed(const Duration(milliseconds: 900));
      if (!mounted) return;
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_rounded,
                          color: Colors.white),
                      onPressed:
                          _isLoading ? null : () => Navigator.pop(context),
                    ),
                    const SizedBox(height: 12),
                    const Center(
                      child: Column(children: [
                        Icon(Icons.person_add_rounded,
                            size: 52, color: Colors.white),
                        SizedBox(height: 10),
                        Text('Criar Conta',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.w900)),
                        SizedBox(height: 4),
                        Text('Junte-se à comunidade',
                            style:
                                TextStyle(color: Colors.white60, fontSize: 14)),
                      ]),
                    ),
                    const SizedBox(height: 20),

                    // Banner offline
                    if (!_online) ...[
                      _bannerOffline(),
                      const SizedBox(height: 16),
                    ],

                    _campo(_nomeController, 'Nome de usuário',
                        Icons.person_outline_rounded,
                        capitalizacao: TextCapitalization.words),
                    const SizedBox(height: 14),
                    _campo(_emailController, 'Email',
                        Icons.email_outlined,
                        tipo: TextInputType.emailAddress),
                    const SizedBox(height: 14),
                    _campo(
                      _senhaController,
                      'Senha (mín. 6 caracteres)',
                      Icons.lock_outline_rounded,
                      obscure: !_senhaVisivel,
                      sufixo: _olhoBtn(
                          () => setState(
                              () => _senhaVisivel = !_senhaVisivel),
                          _senhaVisivel),
                    ),
                    const SizedBox(height: 14),
                    _campo(
                      _confirmarController,
                      'Confirmar senha',
                      Icons.lock_outline_rounded,
                      obscure: !_confirmarVisivel,
                      onSubmit: (_) => _cadastrar(),
                      sufixo: _olhoBtn(
                          () => setState(
                              () => _confirmarVisivel = !_confirmarVisivel),
                          _confirmarVisivel),
                    ),
                    const SizedBox(height: 28),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _cadastrar,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF7C3AED),
                          elevation: 0,
                          padding:
                              const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Color(0xFF7C3AED)))
                            : Text(
                                _online
                                    ? 'Cadastrar'
                                    : 'Cadastrar offline',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16)),
                      ),
                    ),
                    const SizedBox(height: 12),

                    Center(
                      child: TextButton(
                        onPressed: _isLoading
                            ? null
                            : () => Navigator.pushReplacementNamed(
                                context, AppRoutes.login),
                        child: const Text('Já tem conta? Entrar',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600)),
                      ),
                    ),
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
              'Sem conexão. Sua conta será criada localmente e sincronizada quando você conectar.',
              style: TextStyle(
                  color: Colors.white.withOpacity(0.85), fontSize: 12),
            ),
          ),
        ]),
      );

  Widget _campo(
    TextEditingController c,
    String hint,
    IconData icon, {
    bool obscure = false,
    TextInputType tipo = TextInputType.text,
    TextCapitalization capitalizacao = TextCapitalization.none,
    Widget? sufixo,
    void Function(String)? onSubmit,
  }) =>
      TextField(
        controller: c,
        obscureText: obscure,
        keyboardType: tipo,
        textCapitalization: capitalizacao,
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

  Widget _olhoBtn(VoidCallback onTap, bool visivel) => IconButton(
      icon: Icon(
          visivel ? Icons.visibility_off : Icons.visibility,
          color: Colors.white60),
      onPressed: onTap);
}