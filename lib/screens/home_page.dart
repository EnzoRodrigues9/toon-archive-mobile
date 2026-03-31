import 'dart:async';
import 'package:flutter/material.dart';
import '../../widgets/obra_card.dart';
import 'comunidade_page.dart';
import 'downloads_page.dart';
import '../services/favoritos_service.dart';

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
  List<String> favoritos = [];

  final List<Map<String, String>> obras = [
    {'titulo': 'Naruto', 'descricao': 'Aventura ninja clássica'},
    {'titulo': 'One Piece', 'descricao': 'Piratas em busca do tesouro'},
    {'titulo': 'Attack on Titan', 'descricao': 'Humanidade contra titãs'},
  ];

  List<Map<String, String>> obrasFiltradas = [];

  final List<Map<String, String>> banners = [
    {
      'imagem': 'assets/kagurabachibanner.jpg',
      'titulo': 'Kagurabachi',
      'subtitulo': 'Uma jornada sombria com ação intensa',
    },
    {
      'imagem': 'assets/bannernaruto.jpg',
      'titulo': 'Naruto',
      'subtitulo': 'O clássico ninja que marcou gerações',
    },
    {
      'imagem': 'assets/bannerjjk2.jpg',
      'titulo': 'Jujutsu Kaisen',
      'subtitulo': 'Feitiçaria, maldições e batalhas eletrizantes',
    },
  ];

  final PageController _pageController = PageController(viewportFraction: 0.94);
  int _paginaBanner = 0;
  Timer? _bannerTimer;

  @override
  void initState() {
    super.initState();
    obrasFiltradas = obras;
    carregarFavoritos();
    iniciarAutoPlayBanner();
  }

  @override
  void dispose() {
    _bannerTimer?.cancel();
    _pageController.dispose();
    pesquisaController.dispose();
    super.dispose();
  }

  void iniciarAutoPlayBanner() {
    _bannerTimer?.cancel();

    _bannerTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (!mounted) return;
      if (paginaAtual != 0) return;
      if (banners.isEmpty) return;
      if (!_pageController.hasClients) return;

      final proximaPagina = (_paginaBanner + 1) % banners.length;

      _pageController.animateToPage(
        proximaPagina,
        duration: const Duration(milliseconds: 550),
        curve: Curves.easeInOut,
      );
    });
  }

  Future<void> carregarFavoritos() async {
    favoritos = await FavoritosService.getFavoritos();
    if (!mounted) return;
    filtrarObras(pesquisaController.text);
  }

  void filtrarObras(String texto) {
    List<Map<String, String>> filtradas = obras.where((obra) {
      final titulo = obra['titulo']!.toLowerCase();
      final descricao = obra['descricao']!.toLowerCase();
      final busca = texto.toLowerCase();
      return titulo.contains(busca) || descricao.contains(busca);
    }).toList();

    if (mostrarFavoritos) {
      filtradas = filtradas
          .where((obra) => favoritos.contains(obra['titulo']))
          .toList();
    }

    setState(() {
      obrasFiltradas = filtradas;
    });
  }

  Future<void> toggleMostrarFavoritos() async {
    await carregarFavoritos();
    setState(() {
      mostrarFavoritos = !mostrarFavoritos;
    });
    filtrarObras(pesquisaController.text);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final Color roxoPrincipal = isDark
        ? const Color(0xFFB388FF)
        : const Color(0xFF8B5CF6);

    final Color roxoSecundario = isDark
        ? const Color(0xFFD1C4E9)
        : const Color(0xFFC4B5FD);

    final Color fundoPagina = isDark
        ? const Color(0xFF140F1F)
        : const Color(0xFFF6F2FF);

    final paginas = [
      Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              fundoPagina,
              isDark ? const Color(0xFF1B132B) : const Color(0xFFEFE6FF),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // HEADER ESTILO LOGO
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 20,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(26),
                    gradient: LinearGradient(
                      colors: [
                        roxoPrincipal.withOpacity(0.98),
                        roxoSecundario.withOpacity(0.92),
                      ],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: roxoPrincipal.withOpacity(0.28),
                        blurRadius: 22,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          RichText(
                            textAlign: TextAlign.center,
                            text: TextSpan(
                              children: [
                                TextSpan(
                                  text: 'TOON\n',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 2.5,
                                    color: Colors.white,
                                    height: 0.9,
                                    shadows: [
                                      Shadow(
                                        color: Colors.black.withOpacity(0.25),
                                        blurRadius: 10,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                ),
                                TextSpan(
                                  text: 'ARCHIVE',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 3.5,
                                    color: const Color(0xFFEDE9FE),
                                    height: 1.0,
                                    shadows: [
                                      Shadow(
                                        color: Colors.black.withOpacity(0.25),
                                        blurRadius: 10,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            width: 120,
                            height: 3,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(999),
                              gradient: LinearGradient(
                                colors: [
                                  Colors.white.withOpacity(0),
                                  Colors.white.withOpacity(0.9),
                                  Colors.white.withOpacity(0),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Material(
                          color: Colors.white.withOpacity(0.14),
                          borderRadius: BorderRadius.circular(16),
                          child: IconButton(
                            tooltip: 'Alternar tema',
                            onPressed: widget.alternarTema,
                            icon: const Icon(Icons.dark_mode_rounded),
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                // CARROSSEL
                SizedBox(
                  height: 215,
                  child: Stack(
                    children: [
                      PageView.builder(
                        controller: _pageController,
                        itemCount: banners.length,
                        onPageChanged: (index) {
                          setState(() {
                            _paginaBanner = index;
                          });
                        },
                        itemBuilder: (context, index) {
                          final banner = banners[index];

                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: [
                                BoxShadow(
                                  color: roxoPrincipal.withOpacity(0.18),
                                  blurRadius: 18,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(24),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  Image.asset(
                                    banner['imagem']!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        color: const Color(0xFF2A1D3D),
                                        alignment: Alignment.center,
                                        child: Padding(
                                          padding: const EdgeInsets.all(16),
                                          child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              const Icon(
                                                Icons.broken_image_rounded,
                                                color: Colors.white70,
                                                size: 42,
                                              ),
                                              const SizedBox(height: 10),
                                              Text(
                                                'Erro ao carregar:\n${banner['imagem']}',
                                                textAlign: TextAlign.center,
                                                style: const TextStyle(
                                                  color: Colors.white70,
                                                  fontSize: 13,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                  Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Colors.black.withOpacity(0.75),
                                          Colors.black.withOpacity(0.26),
                                          Colors.transparent,
                                        ],
                                        begin: Alignment.bottomLeft,
                                        end: Alignment.topRight,
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(18),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 5,
                                          ),
                                          decoration: BoxDecoration(
                                            color: roxoPrincipal.withOpacity(
                                              0.88,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              999,
                                            ),
                                          ),
                                          child: const Text(
                                            'Destaque',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 10),
                                        Text(
                                          banner['titulo']!,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 24,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          banner['subtitulo']!,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 13.5,
                                            height: 1.35,
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        ElevatedButton.icon(
                                          onPressed: () {
                                            pesquisaController.text =
                                                banner['titulo']!;
                                            filtrarObras(banner['titulo']!);
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.white,
                                            foregroundColor: roxoPrincipal,
                                            elevation: 0,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 14,
                                              vertical: 10,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                            ),
                                          ),
                                          icon: const Icon(Icons.play_arrow),
                                          label: const Text('Ver obra'),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),

                      Positioned(
                        bottom: 12,
                        left: 0,
                        right: 0,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(banners.length, (index) {
                            final ativo = _paginaBanner == index;

                            return GestureDetector(
                              onTap: () {
                                _pageController.animateToPage(
                                  index,
                                  duration: const Duration(milliseconds: 400),
                                  curve: Curves.easeInOut,
                                );
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 250),
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                width: ativo ? 22 : 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: ativo
                                      ? Colors.white
                                      : Colors.white.withOpacity(0.45),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                              ),
                            );
                          }),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                // PESQUISA + FAVORITOS
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withOpacity(0.05)
                        : Colors.white.withOpacity(0.82),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: roxoPrincipal.withOpacity(0.18)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(isDark ? 0.12 : 0.05),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: pesquisaController,
                          onChanged: filtrarObras,
                          style: TextStyle(
                            fontSize: 14.5,
                            color: theme.textTheme.bodyLarge?.color,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Pesquisar obra...',
                            hintStyle: TextStyle(
                              color: isDark ? Colors.white60 : Colors.black54,
                            ),
                            prefixIcon: Icon(
                              Icons.search_rounded,
                              color: roxoPrincipal,
                            ),
                            suffixIcon: pesquisaController.text.isNotEmpty
                                ? IconButton(
                                    icon: Icon(
                                      Icons.clear_rounded,
                                      color: roxoPrincipal,
                                    ),
                                    onPressed: () {
                                      pesquisaController.clear();
                                      filtrarObras('');
                                    },
                                  )
                                : null,
                            filled: true,
                            fillColor: isDark
                                ? const Color(0xFF241A35)
                                : const Color(0xFFF8F4FF),
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 14,
                              horizontal: 14,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(
                                color: roxoPrincipal.withOpacity(0.10),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(
                                color: roxoPrincipal,
                                width: 1.4,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: mostrarFavoritos
                                ? [
                                    Colors.amber.shade700,
                                    Colors.orange.shade400,
                                  ]
                                : [
                                    roxoPrincipal.withOpacity(0.92),
                                    roxoSecundario.withOpacity(0.92),
                                  ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: IconButton(
                          tooltip: mostrarFavoritos
                              ? 'Mostrar todas'
                              : 'Filtrar favoritos',
                          onPressed: toggleMostrarFavoritos,
                          icon: Icon(
                            mostrarFavoritos
                                ? Icons.star_rounded
                                : Icons.star_border_rounded,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                Row(
                  children: [
                    Icon(
                      Icons.local_fire_department_rounded,
                      color: roxoPrincipal,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      mostrarFavoritos ? 'Seus favoritos' : 'Obras em alta',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: roxoPrincipal,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                Expanded(
                  child: obrasFiltradas.isEmpty
                      ? Center(
                          child: Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white.withOpacity(0.05)
                                  : Colors.white.withOpacity(0.75),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: roxoPrincipal.withOpacity(0.12),
                              ),
                            ),
                            child: const Text(
                              'Nenhuma obra encontrada',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.only(bottom: 14),
                          itemCount: obrasFiltradas.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final obra = obrasFiltradas[index];
                            return ObraCard(
                              titulo: obra['titulo']!,
                              descricao: obra['descricao']!,
                              onFavoritoAlterado: carregarFavoritos,
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
      const ComunidadePage(),
      const DownloadsPage(),
    ];

    return Scaffold(
      backgroundColor: fundoPagina,
      body: paginas[paginaAtual],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [const Color(0xFF221632), const Color(0xFF2C1C45)]
                : [const Color(0xFFEDE4FF), const Color(0xFFE3D7FF)],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 14,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: paginaAtual,
          onTap: (index) {
            setState(() {
              paginaAtual = index;
            });

            if (index == 0) {
              iniciarAutoPlayBanner();
            }
          },
          backgroundColor: Colors.transparent,
          elevation: 0,
          selectedItemColor: roxoPrincipal,
          unselectedItemColor: isDark ? Colors.white60 : Colors.black54,
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_rounded),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.chat_bubble_rounded),
              label: 'Comunidade',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.download_rounded),
              label: 'Downloads',
            ),
          ],
        ),
      ),
    );
  }
}
