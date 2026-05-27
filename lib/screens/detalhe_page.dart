import 'package:flutter/material.dart';
import '../repositories/favoritos_repository.dart';
import '../repositories/downloads_repository.dart';
import '../repositories/capitulos_repository.dart';
import '../repositories/paginas_repository.dart';
import '../services/auth_service.dart';
import '../services/download_service.dart';
import '../models/capitulo.dart';
import '../repositories/generos_repository.dart';
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
  // true = crescente (cap 1 → N), false = decrescente
  bool _ordemCrescente = true;

  List<Genero> _generos = [];
  final _generosRepo = GenerosRepository.instance;

  // Lista SEMPRE ordenada de forma canônica (crescente).
  // A exibição inverte conforme _ordemCrescente, mas a ordem real
  // nunca é alterada para não quebrar a navegação.
  List<Capitulo> _capitulos = [];

  final Map<String, bool> _downloadsConcluidos = {};
  final Map<String, bool> _baixando = {};
  final Map<String, (int, int)> _progresso = {};

  final _favoritosRepo = FavoritosRepository.instance;
  final _downloadsRepo = DownloadsRepository.instance;
  final _capitulosRepo = CapitulosRepository.instance;
  final _paginasRepo = PaginasRepository.instance;
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
    await Future.wait(
        [_carregarFavorito(), _carregarCapitulos(), _carregarGeneros()]);
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

    // Ordem canônica SEMPRE crescente
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

  /// Retorna a lista a exibir (crescente ou decrescente) sem alterar _capitulos.
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
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  String _descricao() {
    const m = {
      'One Piece': 'Uma grande aventura pirata em busca do tesouro lendário.',
      'Naruto': 'A jornada de um ninja determinado a se tornar Hokage.',
      'Attack on Titan':
          'A luta da humanidade contra os titãs em um mundo cruel.',
      'Kagurabachi': 'A busca por espadas mágicas numa aventura sombria.',
      'Jujutsu Kaisen': 'Feiticeiros contra maldições em batalhas épicas.',
    };
    return m[widget.titulo] ?? 'Acompanhe os capítulos e continue sua leitura.';
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
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1A1030) : roxo,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text('Toon Archive',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
        actions: [
          _carregando
              ? const Padding(
                  padding: EdgeInsets.all(14),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  ))
              : IconButton(
                  icon: Icon(
                    _isFavorito
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    color: Colors.white,
                  ),
                  onPressed: _toggleFavorito,
                ),
        ],
      ),
      body: Column(
        children: [
          // ── Cabeçalho da obra ─────────────────────────────
          Container(
            margin: const EdgeInsets.fromLTRB(14, 14, 14, 0),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: LinearGradient(
                colors: isDark
                    ? [const Color(0xFF2D1B5E), const Color(0xFF1A1030)]
                    : [roxo, const Color(0xFF9F67FA)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                    color: roxo.withOpacity(0.22),
                    blurRadius: 16,
                    offset: const Offset(0, 6)),
              ],
            ),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(widget.titulo,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              Text(_descricao(),
                  style: const TextStyle(
                      color: Colors.white70, fontSize: 13, height: 1.4)),
              const SizedBox(height: 14),
// Substitui o Wrap existente com _chip('${_capitulos.length} capítulos') etc.
              Wrap(spacing: 6, runSpacing: 6, children: [
                _chip('${_capitulos.length} cap.'),
                // Tipo (Mangá, HQ...)
                ..._generos
                    .where((g) => g.categoria == 'tipo')
                    .map((g) => _chip(g.nome)),
                // Demográfico
                ..._generos
                    .where((g) => g.categoria == 'demografico')
                    .map((g) => _chip(g.nome)),
              ]),
              const SizedBox(height: 8),
// Narrativos em linha separada com cor diferente
              if (_generos.any((g) => g.categoria == 'narrativo'))
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: _generos
                      .where((g) => g.categoria == 'narrativo')
                      .map((g) => Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.10),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                  color: Colors.white.withOpacity(0.3)),
                            ),
                            child: Text(g.nome,
                                style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600)),
                          ))
                      .toList(),
                ),
            ]),
          ),

          // ── Barra de controle da lista ────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
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
                child: Text(
                  '${_capitulos.length}',
                  style: TextStyle(
                      color: roxo, fontWeight: FontWeight.w800, fontSize: 12),
                ),
              ),
              const Spacer(),
              // Botão de ordenação
              GestureDetector(
                onTap: () => setState(() => _ordemCrescente = !_ordemCrescente),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
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
                          fontSize: 12,
                          color: roxo,
                          fontWeight: FontWeight.w700),
                    ),
                  ]),
                ),
              ),
            ]),
          ),

          // Divisor
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Divider(color: roxo.withOpacity(0.12), height: 1),
          ),

          // ── Lista de capítulos ────────────────────────────
          Expanded(
            child: _carregandoCaps
                ? const Center(child: CircularProgressIndicator())
                : _capitulos.isEmpty
                    ? _estadoVazio(roxo)
                    : RefreshIndicator(
                        onRefresh: _carregarCapitulos,
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(14, 10, 14, 20),
                          itemCount: _capitulosExibidos.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (_, i) => _buildCapituloCard(
                            _capitulosExibidos[i],
                            isDark,
                            roxo,
                            card,
                          ),
                        ),
                      ),
          ),
        ],
      ),
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
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: roxo.withOpacity(0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.14 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
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
              // Número do capítulo
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [roxo, roxo.withOpacity(0.7)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(13),
                ),
                alignment: Alignment.center,
                child: Text(
                  '${cap.numero}',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 15),
                ),
              ),
              const SizedBox(width: 12),
              // Título + badge offline
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(
                      cap.titulo,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 3),
                    if (baixado)
                      Row(children: [
                        Icon(Icons.offline_pin_rounded,
                            size: 13, color: Colors.green.shade400),
                        const SizedBox(width: 4),
                        Text('Disponível offline',
                            style: TextStyle(
                                fontSize: 11, color: Colors.green.shade400)),
                      ])
                    else
                      Text('Toque para ler',
                          style: TextStyle(
                              fontSize: 11,
                              color: isDark ? Colors.white38 : Colors.black38)),
                  ])),
              // Botão download / deletar
              eBaixando
                  ? Padding(
                      padding: const EdgeInsets.all(10),
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: roxo),
                      ))
                  : IconButton(
                      icon: Icon(
                        baixado ? Icons.delete_rounded : Icons.download_rounded,
                        color: baixado ? Colors.redAccent : roxo,
                      ),
                      onPressed: () => baixado
                          ? _removerDownload(cap)
                          : _baixarCapitulo(cap.id),
                    ),
              // Seta de leitura
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: roxo.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.chevron_right_rounded, color: roxo, size: 20),
              ),
            ]),
            // Barra de progresso de download
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

  Widget _estadoVazio(Color roxo) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: roxo.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
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

  Widget _chip(String texto) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.16),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(texto,
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 12)),
      );
}
