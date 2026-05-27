import 'package:flutter/material.dart';
import '../repositories/favoritos_repository.dart';
import '../repositories/downloads_repository.dart';
import '../repositories/capitulos_repository.dart';
import '../repositories/paginas_repository.dart';
import '../repositories/obras_repository.dart';
import '../repositories/generos_repository.dart';
import '../services/auth_service.dart';
import '../services/download_service.dart';
import '../models/capitulo.dart';
import '../models/obra.dart';
import '../models/genero.dart';
import 'dart:io';

class DetalhePage extends StatefulWidget {
  final String obraId;
  final String titulo;
  const DetalhePage({super.key, required this.obraId, required this.titulo});
  @override
  State<DetalhePage> createState() => _DetalhePageState();
}

class _DetalhePageState extends State<DetalhePage> {
  bool _isFavorito = false, _carregando = true, _carregandoCaps = true;
  String? _usuarioId;
  bool _ordemCrescente = true;
  bool _descricaoExpandida = false;

  Obra? _obra;
  List<Capitulo> _capitulos = [];
  List<Genero> _generos = [];

  final Map<String, bool> _downloadsConcluidos = {};
  final Map<String, bool> _baixando = {};
  final Map<String, (int, int)> _progresso = {};

  final _favoritosRepo = FavoritosRepository.instance;
  final _downloadsRepo = DownloadsRepository.instance;
  final _capitulosRepo = CapitulosRepository.instance;
  final _paginasRepo = PaginasRepository.instance;
  final _obrasRepo = ObrasRepository.instance;
  final _generosRepo = GenerosRepository.instance;
  final _downloadService = DownloadService.instance;
  final _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _inicializar();
  }

  Future<void> _inicializar() async {
    final u = await _authService.getUsuarioInterno();
    if (!mounted) return;
    _usuarioId = u?.id;
    await Future.wait([
      _carregarObra(),
      _carregarFavorito(),
      _carregarCapitulos(),
      _carregarGeneros(),
    ]);
  }

  Future<void> _carregarObra() async {
    final obra = await _obrasRepo.buscarPorId(widget.obraId);
    if (!mounted) return;
    setState(() => _obra = obra);
  }

  Future<void> _carregarGeneros() async {
    final generos = await _generosRepo.listarPorObra(widget.obraId);
    if (!mounted) return;
    setState(() => _generos = generos);
  }

  Future<void> _carregarFavorito() async {
    if (_usuarioId == null) {
      if (mounted) setState(() => _carregando = false);
      return;
    }
    final fav = await _favoritosRepo.isFavorito(_usuarioId!, widget.obraId);
    if (!mounted) return;
    setState(() {
      _isFavorito = fav;
      _carregando = false;
    });
  }

  Future<void> _carregarCapitulos() async {
    setState(() => _carregandoCaps = true);
    final lista = await _capitulosRepo.listarPorObra(widget.obraId);
    if (!mounted) return;
    lista.sort((a, b) => a.numero.compareTo(b.numero));
    if (_usuarioId != null) {
      for (final c in lista) {
        _downloadsConcluidos[c.id] =
            await _downloadsRepo.jaDownloaded(_usuarioId!, c.id);
      }
    }
    if (!mounted) return;
    setState(() {
      _capitulos = lista;
      _carregandoCaps = false;
    });
  }

  List<Capitulo> get _capitulosExibidos =>
      _ordemCrescente ? _capitulos : _capitulos.reversed.toList();

  Future<void> _toggleFavorito() async {
    if (_usuarioId == null) {
      _snack('Faça login para favoritar.');
      return;
    }
    setState(() => _isFavorito = !_isFavorito);
    try {
      await _favoritosRepo.toggle(_usuarioId!, widget.obraId);
    } catch (_) {
      if (mounted) setState(() => _isFavorito = !_isFavorito);
    }
  }

  Future<void> _baixarCapitulo(String capituloId) async {
    if (_usuarioId == null) {
      _snack('Faça login para baixar.');
      return;
    }
    if (await _downloadsRepo.jaDownloaded(_usuarioId!, capituloId)) {
      _snack('Já baixado.');
      return;
    }
    setState(() {
      _baixando[capituloId] = true;
      _progresso[capituloId] = (0, 0);
    });
    try {
      await _downloadsRepo.iniciar(_usuarioId!, capituloId);
      await _downloadsRepo.atualizarStatus(_usuarioId!, capituloId,
          status: 'baixando');
      final paginas = await _paginasRepo.listarPorCapitulo(capituloId);
      if (paginas.isEmpty) throw Exception('Nenhuma página encontrada.');
      final caminhos = await _downloadService.baixarCapitulo(
        obraId: widget.obraId,
        capituloId: capituloId,
        paginas: paginas,
        onProgresso: (b, t) {
          if (mounted) setState(() => _progresso[capituloId] = (b, t));
        },
      );
      for (final p in paginas) {
        final c = caminhos[p.id];
        if (c != null)
          await _paginasRepo.atualizarImagemLocal(
              paginaId: p.id, caminhoLocal: c);
      }
      await _capitulosRepo.marcarOffline(capituloId);
      await _downloadsRepo.atualizarStatus(_usuarioId!, capituloId,
          status: 'concluido', caminhoLocal: '${widget.obraId}/$capituloId');
      if (!mounted) return;
      setState(() => _downloadsConcluidos[capituloId] = true);
      _snack('Capítulo baixado!');
    } catch (e) {
      await _downloadsRepo.atualizarStatus(_usuarioId!, capituloId,
          status: 'erro');
      if (!mounted) return;
      _snack('Erro: $e');
    } finally {
      if (mounted)
        setState(() {
          _baixando.remove(capituloId);
          _progresso.remove(capituloId);
        });
    }
  }

  Future<void> _removerDownload(Capitulo cap) async {
    if (_usuarioId == null) return;
    try {
      await _downloadService.removerArquivosCapitulo(
          obraId: widget.obraId, capituloId: cap.id);
      final ps = await _paginasRepo.listarPorCapitulo(cap.id);
      for (final p in ps) {
        if (p.imagemLocal != null) {
          await _paginasRepo.atualizarImagemLocal(
              paginaId: p.id, caminhoLocal: '');
        }
      }
      await _capitulosRepo.removerOffline(cap.id);
      await _downloadsRepo.remover(_usuarioId!, cap.id);
      if (!mounted) return;
      setState(() => _downloadsConcluidos[cap.id] = false);
      _snack('Download removido.');
    } catch (e) {
      _snack('Erro: $e');
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating));
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'em_andamento':
        return 'Em andamento';
      case 'completa':
        return 'Completa';
      case 'hiato':
        return 'Hiato';
      case 'cancelada':
        return 'Cancelada';
      default:
        return status;
    }
  }

  // =========================================================
  // BUILD
  // =========================================================

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final roxo = isDark ? const Color(0xFF9F67FA) : const Color(0xFF7C3AED);
    final fundo = isDark ? const Color(0xFF0F0A1E) : const Color(0xFFF5F3FF);
    final card = isDark ? const Color(0xFF1A1030) : Colors.white;

    return Scaffold(
      backgroundColor: fundo,
      body: CustomScrollView(
        slivers: [
          // ── SliverAppBar com capa ──────────────────────────
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            backgroundColor: isDark ? const Color(0xFF1A1030) : roxo,
            foregroundColor: Colors.white,
            actions: [
              _carregando
                  ? const Padding(
                      padding: EdgeInsets.all(14),
                      child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white)))
                  : IconButton(
                      icon: Icon(
                        _isFavorito
                            ? Icons.bookmark_rounded
                            : Icons.bookmark_border_rounded,
                        color: Colors.white,
                      ),
                      onPressed: _toggleFavorito,
                    ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: _buildHeroBanner(isDark, roxo),
            ),
          ),

          // ── Corpo ──────────────────────────────────────────
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoSection(isDark, roxo, card),
                _buildGenerosSection(isDark, roxo),
                _buildDescricaoSection(isDark, roxo),
                _buildCapitulosHeader(isDark, roxo),
              ],
            ),
          ),

          // ── Lista de capítulos ─────────────────────────────
          if (_carregandoCaps)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_capitulos.isEmpty)
            SliverFillRemaining(child: _estadoVazio(roxo))
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 30),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, i) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _buildCapituloCard(
                        _capitulosExibidos[i], isDark, roxo, card),
                  ),
                  childCount: _capitulosExibidos.length,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // =========================================================
  // HERO BANNER — capa + overlay com título
  // =========================================================

  Widget _buildHeroBanner(bool isDark, Color roxo) {
    final capaUrl = _obra?.capaUrl;
    final bannerUrl = _obra?.bannerUrl;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Fundo: banner (se tiver), senão capa, senão gradiente
        if (bannerUrl != null && bannerUrl.isNotEmpty)
          Image.network(bannerUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _gradienteFundo(isDark, roxo))
        else if (capaUrl != null && capaUrl.isNotEmpty)
          Image.network(capaUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _gradienteFundo(isDark, roxo))
        else
          _gradienteFundo(isDark, roxo),

        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.transparent,
                Colors.black.withOpacity(0.55),
                Colors.black.withOpacity(0.88),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: const [0.3, 0.65, 1.0],
            ),
          ),
        ),
        // Gradiente escuro sobre a imagem
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.transparent,
                Colors.black.withOpacity(0.55),
                Colors.black.withOpacity(0.88),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: const [0.3, 0.65, 1.0],
            ),
          ),
        ),

        // Conteúdo sobre o banner: capa pequena + título + autor
        // Miniatura da capa + título + autor (igual ao anterior)
        Positioned(
          left: 16,
          right: 16,
          bottom: 16,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 90,
                  height: 130,
                  child: capaUrl != null && capaUrl.isNotEmpty
                      ? Image.network(capaUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                                color: roxo.withOpacity(0.5),
                                child: const Icon(Icons.menu_book_rounded,
                                    color: Colors.white, size: 32),
                              ))
                      : Container(
                          color: roxo.withOpacity(0.5),
                          child: const Icon(Icons.menu_book_rounded,
                              color: Colors.white, size: 32),
                        ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(widget.titulo,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            height: 1.2)),
                    if (_obra?.autor?.isNotEmpty ?? false) ...[
                      const SizedBox(height: 4),
                      Text(_obra!.autor!,
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.75),
                              fontSize: 13,
                              fontWeight: FontWeight.w500)),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _gradienteFundo(bool isDark, Color roxo) => Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [const Color(0xFF2D1B5E), const Color(0xFF1A1030)]
                : [roxo, const Color(0xFF9F67FA)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
      );

  // =========================================================
  // INFO — status + total caps + botão iniciar
  // =========================================================

  Widget _buildInfoSection(bool isDark, Color roxo, Color card) {
    final status = _obra?.status ?? 'em_andamento';

    return Container(
      color: card,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(children: [
        // Status
        _tagChip(_statusLabel(status), _statusColor(status)),
        const SizedBox(width: 8),
        // Total capítulos
        _tagChip('${_capitulos.length} cap.', roxo),
        const Spacer(),
        // Botão Iniciar leitura
        if (_capitulos.isNotEmpty)
          ElevatedButton.icon(
            onPressed: () =>
                Navigator.pushNamed(context, '/leitura', arguments: {
              'obraId': widget.obraId,
              'capituloId': _capitulos.first.id,
              'capitulo': _capitulos.first.titulo,
              'titulo': widget.titulo,
            }),
            style: ElevatedButton.styleFrom(
              backgroundColor: roxo,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.play_arrow_rounded, size: 18),
            label: const Text('Iniciar',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
      ]),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'em_andamento':
        return Colors.green;
      case 'completa':
        return Colors.blue;
      case 'hiato':
        return Colors.orange;
      case 'cancelada':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  // =========================================================
  // GÊNEROS
  // =========================================================

  Widget _buildGenerosSection(bool isDark, Color roxo) {
    if (_generos.isEmpty) return const SizedBox.shrink();

    final card = isDark ? const Color(0xFF1A1030) : Colors.white;

    // Agrupa por categoria
    final demografico =
        _generos.where((g) => g.categoria == 'demografico').toList();
    final narrativo =
        _generos.where((g) => g.categoria == 'narrativo').toList();
    final tipo = _generos.where((g) => g.categoria == 'tipo').toList();

    return Container(
      color: card,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Divider(color: roxo.withOpacity(0.10), height: 1),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              // Narrativos — destaque principal
              ...narrativo.map((g) => _tagChip(g.nome, roxo)),
              // Tipo (Mangá, HQ...) — azul acinzentado
              ...tipo.map((g) => _tagChip(g.nome, Colors.blueGrey)),
              // Demográfico — menor destaque
              ...demografico.map((g) =>
                  _tagChip(g.nome, isDark ? Colors.white38 : Colors.black38)),
            ],
          ),
        ],
      ),
    );
  }

  // =========================================================
  // DESCRIÇÃO expansível
  // =========================================================

  Widget _buildDescricaoSection(bool isDark, Color roxo) {
    final descricao = _obra?.descricao ?? '';
    if (descricao.isEmpty) return const SizedBox.shrink();

    final card = isDark ? const Color(0xFF1A1030) : Colors.white;
    final textColor = isDark ? Colors.white70 : Colors.black87;

    return Container(
      color: card,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Divider(color: roxo.withOpacity(0.10), height: 1),
          const SizedBox(height: 12),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 200),
            crossFadeState: _descricaoExpandida
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: Text(descricao,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, color: textColor, height: 1.5)),
            secondChild: Text(descricao,
                style: TextStyle(fontSize: 13, color: textColor, height: 1.5)),
          ),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: () =>
                setState(() => _descricaoExpandida = !_descricaoExpandida),
            child: Text(
              _descricaoExpandida ? 'Ver menos' : 'Ver mais',
              style: TextStyle(
                  color: roxo, fontWeight: FontWeight.w700, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // CABEÇALHO DA LISTA DE CAPÍTULOS
  // =========================================================

  Widget _buildCapitulosHeader(bool isDark, Color roxo) {
    final fundo = isDark ? const Color(0xFF0F0A1E) : const Color(0xFFF5F3FF);
    return Container(
      color: fundo,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: roxo.withOpacity(0.10),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(Icons.menu_book_rounded, color: roxo, size: 18),
        ),
        const SizedBox(width: 8),
        Text('Capítulos',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : Colors.black87)),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: roxo.withOpacity(0.12),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text('${_capitulos.length}',
              style: TextStyle(
                  color: roxo, fontWeight: FontWeight.w800, fontSize: 12)),
        ),
        const Spacer(),
        GestureDetector(
          onTap: () => setState(() => _ordemCrescente = !_ordemCrescente),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: roxo.withOpacity(0.10),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: roxo.withOpacity(0.20)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(
                _ordemCrescente
                    ? Icons.arrow_upward_rounded
                    : Icons.arrow_downward_rounded,
                size: 14,
                color: roxo,
              ),
              const SizedBox(width: 4),
              Text(
                _ordemCrescente ? 'Crescente' : 'Decrescente',
                style: TextStyle(
                    fontSize: 12, color: roxo, fontWeight: FontWeight.w700),
              ),
            ]),
          ),
        ),
      ]),
    );
  }

  // =========================================================
  // CARD DE CAPÍTULO
  // =========================================================

  Widget _buildCapituloCard(Capitulo cap, bool isDark, Color roxo, Color card) {
    final eBaixando = _baixando[cap.id] ?? false;
    final baixado = _downloadsConcluidos[cap.id] ?? false;
    final prog = _progresso[cap.id];

    return Container(
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: roxo.withOpacity(0.10)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.12 : 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2))
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.pushNamed(context, '/leitura', arguments: {
          'obraId': widget.obraId,
          'capituloId': cap.id,
          'capitulo': cap.titulo,
          'titulo': widget.titulo,
        }),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              // Número
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [roxo, roxo.withOpacity(0.7)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Text('${cap.numero}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 14)),
              ),
              const SizedBox(width: 12),
              // Título + badge
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(cap.titulo,
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : Colors.black87)),
                    const SizedBox(height: 2),
                    if (baixado)
                      Row(children: [
                        Icon(Icons.offline_pin_rounded,
                            size: 12, color: Colors.green.shade400),
                        const SizedBox(width: 3),
                        Text('Offline',
                            style: TextStyle(
                                fontSize: 11, color: Colors.green.shade400)),
                      ])
                    else
                      Text('Toque para ler',
                          style: TextStyle(
                              fontSize: 11,
                              color: isDark ? Colors.white38 : Colors.black38)),
                  ])),
              // Download / delete
              eBaixando
                  ? Padding(
                      padding: const EdgeInsets.all(10),
                      child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: roxo)))
                  : IconButton(
                      icon: Icon(
                        baixado ? Icons.delete_rounded : Icons.download_rounded,
                        color: baixado ? Colors.redAccent : roxo,
                      ),
                      onPressed: () => baixado
                          ? _removerDownload(cap)
                          : _baixarCapitulo(cap.id),
                    ),
              // Seta
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: roxo.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.chevron_right_rounded, color: roxo, size: 18),
              ),
            ]),
            // Barra de progresso
            if (eBaixando && prog != null && prog.$2 > 0)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: prog.$1 / prog.$2,
                          minHeight: 4,
                          backgroundColor: roxo.withOpacity(0.15),
                          valueColor: AlwaysStoppedAnimation(roxo),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text('${prog.$1} de ${prog.$2} páginas',
                          style: TextStyle(
                              fontSize: 11, color: roxo.withOpacity(0.7))),
                    ]),
              ),
          ]),
        ),
      ),
    );
  }

  // =========================================================
  // HELPERS
  // =========================================================

  Widget _estadoVazio(Color roxo) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                  color: roxo.withOpacity(0.08), shape: BoxShape.circle),
              child: Icon(Icons.menu_book_outlined,
                  size: 48, color: roxo.withOpacity(0.5)),
            ),
            const SizedBox(height: 16),
            Text('Nenhum capítulo disponível',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: roxo.withOpacity(0.7))),
          ]),
        ),
      );

  Widget _tagChip(String texto, Color cor) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: cor.withOpacity(0.12),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: cor.withOpacity(0.25)),
        ),
        child: Text(texto,
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w700, color: cor)),
      );
}
