import 'package:flutter/material.dart';
import 'leitura_page.dart';
import '../services/favoritos_service.dart';
import 'download_manager.dart';
import '../data/biblioteca.dart';

class DetalhePage extends StatefulWidget {
  final String titulo;

  const DetalhePage({super.key, required this.titulo});

  @override
  State<DetalhePage> createState() => _DetalhePageState();
}

class _DetalhePageState extends State<DetalhePage> {
  bool isFavorito = false;

  @override
  void initState() {
    super.initState();
    carregarFavorito();
  }

  Future<void> carregarFavorito() async {
    final fav = await FavoritosService.isFavorito(widget.titulo);
    if (!mounted) return;
    setState(() {
      isFavorito = fav;
    });
  }

  Future<void> toggleFavorito() async {
    await FavoritosService.toggleFavorito(widget.titulo);
    if (!mounted) return;
    setState(() {
      isFavorito = !isFavorito;
    });
  }

  String getDescricaoObra(String titulo) {
    switch (titulo) {
      case 'One Piece':
        return 'Uma grande aventura pirata em busca do tesouro lendário.';
      case 'Naruto':
        return 'A jornada de um ninja determinado a se tornar Hokage.';
      case 'Attack on Titan':
        return 'A luta da humanidade contra os titãs em um mundo cruel.';
      default:
        return 'Acompanhe os capítulos e continue sua leitura.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final capitulos = biblioteca[widget.titulo]?.keys.toList() ?? [];
    final roxo = Theme.of(context).colorScheme.primary;
    final roxoSecundario = Theme.of(context).colorScheme.secondary;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final fundo = isDark ? const Color(0xFF140F1F) : const Color(0xFFF7F3FF);
    final cardColor = isDark
        ? const Color(0xFF20172C)
        : Colors.white.withOpacity(0.92);

    return Scaffold(
      backgroundColor: fundo,
      appBar: AppBar(
        title: const Text(
          'Toon Archive',
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.5),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(
              isFavorito
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              color: Colors.redAccent,
            ),
            onPressed: toggleFavorito,
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [const Color(0xFF140F1F), const Color(0xFF1C1430)]
                : [const Color(0xFFF7F3FF), const Color(0xFFEFE6FF)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 14, 12, 8),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: LinearGradient(
                    colors: isDark
                        ? [const Color(0xFF2A1D3D), const Color(0xFF3C2860)]
                        : [
                            roxo.withOpacity(0.90),
                            roxoSecundario.withOpacity(0.85),
                          ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: roxo.withOpacity(0.15),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.titulo,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      getDescricaoObra(widget.titulo),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '${capitulos.length} capítulos',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 12.5,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Text(
                            'Leitura rápida',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 12.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
              child: Row(
                children: [
                  Icon(Icons.menu_book_rounded, color: roxo, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Lista de capítulos',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: roxo,
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
                itemCount: capitulos.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final capitulo = capitulos[index];

                  return Material(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(20),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => LeituraPage(
                              capitulo: capitulo,
                              titulo: widget.titulo,
                            ),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: roxo.withOpacity(0.16)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: roxo.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                '${index + 1}',
                                style: TextStyle(
                                  color: roxo,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                capitulo,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Baixar capítulo',
                              icon: Icon(Icons.download_rounded, color: roxo),
                              onPressed: () {
                                final nome = '${widget.titulo} - $capitulo';

                                if (!DownloadManager.downloads.contains(nome)) {
                                  DownloadManager.downloads.add(nome);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Capítulo baixado'),
                                    ),
                                  );
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Esse capítulo já foi baixado',
                                      ),
                                    ),
                                  );
                                }
                              },
                            ),
                            Icon(
                              Icons.arrow_forward_ios_rounded,
                              size: 16,
                              color: roxo.withOpacity(0.8),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
