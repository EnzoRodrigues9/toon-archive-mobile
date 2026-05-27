import 'dart:async';
import 'package:flutter/material.dart';
import '../../widgets/obra_card.dart';
import 'comunidade_page.dart';
import 'downloads_page.dart';
import '../repositories/favoritos_repository.dart';
import '../services/auth_service.dart';
import '../models/obra.dart';
import '../models/usuario.dart';
import '../repositories/obras_repository.dart';
import '../routes/app_routes.dart';

class HomePage extends StatefulWidget {
  final VoidCallback alternarTema;
  const HomePage({super.key, required this.alternarTema});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int paginaAtual = 0;
  final TextEditingController pesquisaController = TextEditingController();
  bool mostrarFavoritos = false;
  List<String> _titulosFavoritos = [];
  String? _usuarioId;
  Usuario? _usuario;

  final _favoritosRepo = FavoritosRepository.instance;
  final _authService = AuthService();
  final _obrasRepo = ObrasRepository.instance;

  List<Obra> _obras = [];
  List<Obra> _obrasFiltradas = [];

  final List<Map<String, String>> banners = [
    {
      'imagem':
          'https://pmbwsfnynuiueyctnujc.supabase.co/storage/v1/object/public/paginas/kagurabachibanner.jpg',
      'titulo': 'Kagurabachi',
      'subtitulo': 'Uma jornada sombria com ação intensa'
    },
    {
      'imagem':
          'https://pmbwsfnynuiueyctnujc.supabase.co/storage/v1/object/public/paginas/bannernaruto.jpg',
      'titulo': 'Naruto',
      'subtitulo': 'O clássico ninja que marcou gerações'
    },
    {
      'imagem':
          'https://pmbwsfnynuiueyctnujc.supabase.co/storage/v1/object/public/paginas/bannerjjk2.jpg',
      'titulo': 'Jujutsu Kaisen',
      'subtitulo': 'Feitiçaria, maldições e batalhas eletrizantes'
    },
  ];

  final PageController _pageController = PageController(viewportFraction: 0.94);
  int _paginaBanner = 0;
  Timer? _bannerTimer;

  @override
  void initState() {
    super.initState();
    _carregarObras();
    _inicializar();
    _iniciarBanner();
  }

  @override
  void dispose() {
    _bannerTimer?.cancel();
    _pageController.dispose();
    pesquisaController.dispose();
    super.dispose();
  }

  Future<void> _inicializar() async {
    final usuario = await _authService.getUsuarioInterno();
    if (!mounted) return;
    _usuario = usuario;
    _usuarioId = usuario?.id;
    await _carregarFavoritos();
  }

  void _iniciarBanner() {
    _bannerTimer?.cancel();
    _bannerTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || paginaAtual != 0 || !_pageController.hasClients) return;
      final proxima = (_paginaBanner + 1) % banners.length;
      _pageController.animateToPage(proxima,
          duration: const Duration(milliseconds: 500), curve: Curves.easeInOut);
    });
  }

  Future<void> _carregarObras() async {
    final obras = await _obrasRepo.listarTodas();
    if (!mounted) return;
    setState(() {
      _obras = obras;
      _obrasFiltradas = obras;
    });
  }

  Future<void> _carregarFavoritos() async {
    if (_usuarioId == null) return;
    final favs = await _favoritosRepo.listarFavoritos(_usuarioId!);
    if (!mounted) return;
    setState(() => _titulosFavoritos = favs.map((o) => o.titulo).toList());
    _filtrar(pesquisaController.text);
  }

  void _filtrar(String texto) {
    List<Obra> lista = _obras.where((o) {
      final t = o.titulo.toLowerCase(),
          d = (o.descricao ?? '').toLowerCase(),
          b = texto.toLowerCase();
      return t.contains(b) || d.contains(b);
    }).toList();
    if (mostrarFavoritos)
      lista = lista.where((o) => _titulosFavoritos.contains(o.titulo)).toList();
    setState(() => _obrasFiltradas = lista);
  }

  Future<void> _toggleFavoritos() async {
    await _carregarFavoritos();
    setState(() => mostrarFavoritos = !mostrarFavoritos);
    _filtrar(pesquisaController.text);
  }

  void _mostrarPerfilUsuario() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true, // ← adicionar
      useSafeArea: true, // ← adicionar
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1030) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: EdgeInsets.fromLTRB(
          // ← era const, agora é dinâmico
          24, 16, 24,
          MediaQuery.of(ctx).padding.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(999))),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [Color(0xFF7C3AED), Color(0xFF9F67FA)]),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.person_rounded,
                  size: 36, color: Colors.white),
            ),
            const SizedBox(height: 14),
            Text(_usuario?.nome ?? 'Usuário',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : Colors.black87)),
            const SizedBox(height: 4),
            Text(_usuario?.email ?? '',
                style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white54 : Colors.black45)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFF7C3AED).withOpacity(0.12),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(_usuario?.role ?? 'leitor',
                  style: const TextStyle(
                      color: Color(0xFF7C3AED),
                      fontWeight: FontWeight.w700,
                      fontSize: 12)),
            ),
            const SizedBox(height: 28),
            Divider(color: Colors.grey.withOpacity(0.2)),
            const SizedBox(height: 12),
            ListTile(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              tileColor:
                  (isDark ? Colors.white : Colors.black).withOpacity(0.04),
              leading: Icon(
                  isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                  color: const Color(0xFF7C3AED)),
              title: Text(isDark ? 'Modo claro' : 'Modo escuro',
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black87)),
              onTap: () {
                Navigator.pop(context);
                widget.alternarTema();
              },
            ),
            const SizedBox(height: 10),
            ListTile(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              tileColor: Colors.redAccent.withOpacity(0.08),
              leading:
                  const Icon(Icons.logout_rounded, color: Colors.redAccent),
              title: const Text('Sair da conta',
                  style: TextStyle(
                      fontWeight: FontWeight.w600, color: Colors.redAccent)),
              onTap: () async {
                Navigator.pop(context);
                try {
                  await _authService
                      .logout()
                      .timeout(const Duration(seconds: 5));
                } catch (_) {}
                if (!mounted) return;
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  AppRoutes.login,
                  (route) => false,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final roxo = isDark ? const Color(0xFF9F67FA) : const Color(0xFF7C3AED);
    final fundo = isDark ? const Color(0xFF0F0A1E) : const Color(0xFFF5F3FF);

    final paginas = [
      _buildHome(isDark, roxo),
      const ComunidadePage(),
      const DownloadsPage()
    ];

    return Scaffold(
      backgroundColor: fundo,
      body: paginas[paginaAtual],
      bottomNavigationBar: _buildNavBar(isDark, roxo),
    );
  }

  Widget _buildNavBar(bool isDark, Color roxo) => Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1030) : Colors.white,
          border: Border(top: BorderSide(color: roxo.withOpacity(0.12))),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 12,
                offset: const Offset(0, -2))
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: paginaAtual,
          onTap: (i) {
            setState(() => paginaAtual = i);
            if (i == 0) _iniciarBanner();
          },
          backgroundColor: Colors.transparent,
          elevation: 0,
          selectedItemColor: roxo,
          unselectedItemColor: isDark ? Colors.white38 : Colors.black38,
          type: BottomNavigationBarType.fixed,
          selectedLabelStyle:
              const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
          items: const [
            BottomNavigationBarItem(
                icon: Icon(Icons.home_rounded), label: 'Home'),
            BottomNavigationBarItem(
                icon: Icon(Icons.chat_bubble_rounded), label: 'Comunidade'),
            BottomNavigationBarItem(
                icon: Icon(Icons.download_rounded), label: 'Downloads'),
          ],
        ),
      );

  Widget _buildHome(bool isDark, Color roxo) {
    final fundo = isDark ? const Color(0xFF0F0A1E) : const Color(0xFFF5F3FF);
    return Container(
      color: fundo,
      child: SafeArea(
        child: Column(
          children: [
            // ── Header ───────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [const Color(0xFF1A1030), const Color(0xFF2D1B5E)]
                      : [const Color(0xFF7C3AED), const Color(0xFF9F67FA)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.menu_book_rounded,
                      color: Colors.white, size: 26),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('TOON ARCHIVE',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 2)),
                          Text('Sua biblioteca de obras',
                              style: TextStyle(
                                  color: Colors.white60, fontSize: 11)),
                        ]),
                  ),
                  // Ícone de usuário
                  GestureDetector(
                    onTap: _mostrarPerfilUsuario,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        shape: BoxShape.circle,
                        border:
                            Border.all(color: Colors.white.withOpacity(0.3)),
                      ),
                      child: const Icon(Icons.person_rounded,
                          color: Colors.white, size: 22),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(14, 16, 14, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Banner ──────────────────────────────
                    _buildBanner(isDark, roxo),
                    const SizedBox(height: 18),
                    // ── Pesquisa ────────────────────────────
                    _buildPesquisa(isDark, roxo),
                    const SizedBox(height: 16),
                    // ── Label ───────────────────────────────
                    Row(children: [
                      Icon(Icons.local_fire_department_rounded,
                          color: roxo, size: 19),
                      const SizedBox(width: 6),
                      Text(
                          mostrarFavoritos ? 'Seus favoritos' : 'Obras em alta',
                          style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: roxo)),
                    ]),
                    const SizedBox(height: 12),
                    // ── Lista ───────────────────────────────
                    _obrasFiltradas.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.symmetric(vertical: 32),
                            child: Center(
                                child: Text('Nenhuma obra encontrada',
                                    style: TextStyle(
                                        color: roxo.withOpacity(0.6)))),
                          )
                        : ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _obrasFiltradas.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
                            itemBuilder: (_, i) => ObraCard(
                                obra: _obrasFiltradas[i],
                                onFavoritoAlterado: _carregarFavoritos),
                          ),
                    const SizedBox(height: 14),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBanner(bool isDark, Color roxo) => SizedBox(
        height: 200,
        child: Stack(
          children: [
            PageView.builder(
              controller: _pageController,
              itemCount: banners.length,
              onPageChanged: (i) => setState(() => _paginaBanner = i),
              itemBuilder: (_, i) {
                final b = banners[i];
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                            color: roxo.withOpacity(0.2),
                            blurRadius: 16,
                            offset: const Offset(0, 8))
                      ]),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Stack(fit: StackFit.expand, children: [
                      Image.network(b['imagem']!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                              color: const Color(0xFF2A1D3D),
                              child: const Icon(Icons.broken_image_rounded,
                                  color: Colors.white38, size: 40))),
                      Container(
                          decoration: BoxDecoration(
                              gradient: LinearGradient(
                                  colors: [
                            Colors.black.withOpacity(0.72),
                            Colors.transparent
                          ],
                                  begin: Alignment.bottomLeft,
                                  end: Alignment.topRight))),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                      color: roxo.withOpacity(0.9),
                                      borderRadius: BorderRadius.circular(999)),
                                  child: const Text('Destaque',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700))),
                              const SizedBox(height: 8),
                              Text(b['titulo']!,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 22,
                                      fontWeight: FontWeight.w900)),
                              Text(b['subtitulo']!,
                                  style: const TextStyle(
                                      color: Colors.white70, fontSize: 12),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 10),
                              ElevatedButton(
                                onPressed: () {
                                  pesquisaController.text = b['titulo']!;
                                  _filtrar(b['titulo']!);
                                },
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor: roxo,
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 8),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(12))),
                                child: const Text('Ver obra',
                                    style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12)),
                              ),
                            ]),
                      ),
                    ]),
                  ),
                );
              },
            ),
            Positioned(
                bottom: 10,
                left: 0,
                right: 0,
                child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(banners.length, (i) {
                      final ativo = _paginaBanner == i;
                      return AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          width: ativo ? 20 : 7,
                          height: 7,
                          decoration: BoxDecoration(
                              color: ativo
                                  ? Colors.white
                                  : Colors.white.withOpacity(0.4),
                              borderRadius: BorderRadius.circular(999)));
                    }))),
          ],
        ),
      );

  Widget _buildPesquisa(bool isDark, Color roxo) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1030) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: roxo.withOpacity(0.15)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 3))
          ],
        ),
        child: Row(children: [
          Expanded(
            child: TextField(
              controller: pesquisaController,
              onChanged: _filtrar,
              style: TextStyle(
                  fontSize: 14, color: isDark ? Colors.white : Colors.black87),
              decoration: InputDecoration(
                hintText: 'Pesquisar obra...',
                hintStyle:
                    TextStyle(color: isDark ? Colors.white38 : Colors.black38),
                prefixIcon: Icon(Icons.search_rounded, color: roxo, size: 20),
                suffixIcon: pesquisaController.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear_rounded, color: roxo, size: 18),
                        onPressed: () {
                          pesquisaController.clear();
                          _filtrar('');
                        })
                    : null,
                filled: true,
                fillColor:
                    isDark ? const Color(0xFF231840) : const Color(0xFFF5F3FF),
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: roxo, width: 1.2)),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _toggleFavoritos,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                    colors: mostrarFavoritos
                        ? [Colors.amber.shade600, Colors.orange.shade400]
                        : [roxo, const Color(0xFF9F67FA)]),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                  mostrarFavoritos
                      ? Icons.star_rounded
                      : Icons.star_border_rounded,
                  color: Colors.white,
                  size: 20),
            ),
          ),
        ]),
      );
}
