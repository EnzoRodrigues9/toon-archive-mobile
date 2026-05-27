import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../repositories/progresso_repository.dart';
import '../repositories/paginas_repository.dart';
import '../repositories/capitulos_repository.dart';
import '../services/auth_service.dart';
import '../models/pagina.dart';
import '../models/capitulo.dart';
import '../models/usuario.dart';

import 'dart:io';

class LeituraPage extends StatefulWidget {
  final String obraId;
  final String capituloId;
  final String capitulo;
  final String titulo;

  const LeituraPage({
    super.key,
    required this.obraId,
    required this.capituloId,
    required this.capitulo,
    required this.titulo,
  });

  @override
  State<LeituraPage> createState() => _LeituraPageState();
}

class _LeituraPageState extends State<LeituraPage>
    with WidgetsBindingObserver {
  bool _disposed = false;
  bool modoClique = false;

  PageController? controller;

  String? _usuarioId;
  String? _obraId;
  Usuario? _usuario;

  final _paginasRepo   = PaginasRepository.instance;
  final _progressoRepo = ProgressoRepository.instance;
  final _authService   = AuthService();
  final _capitulosRepo = CapitulosRepository.instance;
  final _supabase      = Supabase.instance.client;

  final TextEditingController comentarioController = TextEditingController();

  List<Pagina>             _paginas    = [];
  List<Capitulo>           _capitulos  = [];
  List<Map<String, dynamic>> _comentarios = [];

  bool _carregando          = true;
  bool _carregandoComentarios = false;
  bool _enviandoComentario  = false;
  int  _paginaAtual         = 1;

  Capitulo? _capituloAnterior;
  Capitulo? _proximoCapitulo;
  bool _progressoSalvo = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _inicializar();
  }

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _salvarProgressoUmaVez();
    controller?.dispose();
    comentarioController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _salvarProgressoUmaVez();
    }
  }

  void _salvarProgressoUmaVez() {
    if (_progressoSalvo) return;
    _progressoSalvo = true;
    _salvarProgresso();
  }

  void _safeSetState(VoidCallback fn) {
    if (_disposed || !mounted) return;
    setState(fn);
  }

  Future<void> _inicializar() async {
    final usuario = await _authService.getUsuarioInterno();
    if (_disposed) return;
    _usuario   = usuario;
    _usuarioId = usuario?.id;
    _obraId    = widget.obraId;

    await _carregarPaginas();
    if (_disposed) return;
    await _carregarCapitulos();
    if (_disposed) return;
    await _carregarProgresso();
    await _carregarComentarios();
  }

  Future<void> _carregarPaginas() async {
    final paginas = await _paginasRepo.listarPorCapitulo(widget.capituloId);
    if (_disposed) return;
    _safeSetState(() => _paginas = paginas);
  }

  Future<void> _carregarCapitulos() async {
    final lista = await _capitulosRepo.listarPorObra(widget.obraId);
    if (_disposed) return;
    lista.sort((a, b) => a.numero.compareTo(b.numero));
    final indexAtual = lista.indexWhere((c) => c.id == widget.capituloId);
    _safeSetState(() {
      _capitulos        = lista;
      _capituloAnterior = indexAtual > 0 ? lista[indexAtual - 1] : null;
      _proximoCapitulo  = (indexAtual != -1 && indexAtual < lista.length - 1)
          ? lista[indexAtual + 1]
          : null;
    });
  }

  Future<void> _carregarProgresso() async {
    if (_usuarioId == null || _obraId == null) {
      _inicializarController();
      return;
    }
    final progresso = await _progressoRepo.buscarProgresso(
        _usuarioId!, _obraId!);
    if (_disposed) return;
    if (progresso != null && progresso.capituloId == widget.capituloId) {
      _paginaAtual = progresso.ultimaPagina;
    }
    _inicializarController();
  }

  void _inicializarController() {
    if (_disposed) return;
    controller?.dispose();
    controller = PageController(
        initialPage: _paginaAtual > 0 ? _paginaAtual - 1 : 0);
    _safeSetState(() => _carregando = false);
  }

  Future<void> _salvarProgresso() async {
    if (_usuarioId == null || _obraId == null) return;
    try {
      await _progressoRepo.salvarProgresso(
        usuarioId:    _usuarioId!,
        obraId:       _obraId!,
        capituloId:   widget.capituloId,
        ultimaPagina: _paginaAtual,
      );
    } catch (_) {}
  }

  Future<void> _marcarConcluidoSeNecessario(int indexPagina) async {
    if (_usuarioId == null || _obraId == null) return;
    if (indexPagina == _paginas.length - 1) {
      try {
        await _progressoRepo.marcarConcluido(
          usuarioId:  _usuarioId!,
          obraId:     _obraId!,
          capituloId: widget.capituloId,
        );
      } catch (_) {}
    }
  }

  // =========================================================
  // COMENTÁRIOS — Supabase
  // =========================================================

Future<void> _carregarComentarios() async {
  _safeSetState(() => _carregandoComentarios = true);
  try {
    final rows = await _supabase
        .from('comentarios')
        .select('*, usuarios(nome)')
        .eq('obra_id', widget.obraId)
        .eq('capitulo_id', widget.capituloId) 
        .order('criado_em', ascending: true);

    if (_disposed) return;
    _safeSetState(() {
      _comentarios = List<Map<String, dynamic>>.from(rows);
      _carregandoComentarios = false;
    });
  } catch (e) {
    if (_disposed) return;
    _safeSetState(() => _carregandoComentarios = false);
  }
}

Future<void> _adicionarComentario() async {
  final texto = comentarioController.text.trim();
  if (texto.isEmpty || _enviandoComentario) return;
  if (_usuario == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Faça login para comentar.')),
    );
    return;
  }

  _safeSetState(() => _enviandoComentario = true);
  comentarioController.clear();

  try {
    final row = await _supabase
        .from('comentarios')
        .insert({
          'usuario_id':  _usuario!.id,
          'obra_id':     widget.obraId,
          'capitulo_id': widget.capituloId, 
          'conteudo':    texto,
        })
        .select('*, usuarios(nome)')
        .single();

    if (_disposed) return;
    _safeSetState(() {
      _comentarios.add(row);
      _enviandoComentario = false;
    });
  } catch (e) {
    if (_disposed) return;
    _safeSetState(() => _enviandoComentario = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Erro ao comentar: $e')),
    );
  }
}

  Future<void> _editarComentario(Map<String, dynamic> comentario) async {
    comentarioController.text = comentario['conteudo'];
    final salvar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Editar comentário'),
        content: TextField(
            controller: comentarioController,
            autofocus: true,
            maxLines: null),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Salvar')),
        ],
      ),
    );

    if (salvar != true || comentarioController.text.trim().isEmpty) {
      comentarioController.clear();
      return;
    }

    try {
      await _supabase
          .from('comentarios')
          .update({
            'conteudo':      comentarioController.text.trim(),
            'editado':       1,
            'atualizado_em': DateTime.now().toIso8601String(),
          })
          .eq('id', comentario['id']);

      if (_disposed) return;
      _safeSetState(() {
        final i =
            _comentarios.indexWhere((c) => c['id'] == comentario['id']);
        if (i != -1) {
          _comentarios[i]['conteudo'] =
              comentarioController.text.trim();
          _comentarios[i]['editado'] = 1;
        }
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao editar: $e')),
      );
    }
    comentarioController.clear();
  }

  Future<void> _excluirComentario(Map<String, dynamic> comentario) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Excluir comentário'),
        content:
            const Text('Tem certeza que deseja excluir este comentário?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Excluir',
                  style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );

    if (confirmar != true) return;

    try {
      await _supabase
          .from('comentarios')
          .delete()
          .eq('id', comentario['id']);

      if (_disposed) return;
      _safeSetState(() =>
          _comentarios.removeWhere((c) => c['id'] == comentario['id']));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao excluir: $e')),
      );
    }
  }

  bool _eMeuComentario(Map<String, dynamic> comentario) =>
      comentario['usuario_id'] == _usuario?.id;

  String _formatarData(String iso) {
    final dt = DateTime.parse(iso).toLocal();
    return DateFormat('dd/MM/yyyy HH:mm').format(dt);
  }

  // =========================================================
  // NAVEGAÇÃO ENTRE CAPÍTULOS
  // =========================================================

  Future<void> _irParaCapitulo(Capitulo cap) async {
    _salvarProgressoUmaVez();
    if (!mounted) return;
    Navigator.pushReplacementNamed(
      context,
      '/leitura',
      arguments: {
        'obraId':     widget.obraId,
        'capituloId': cap.id,
        'capitulo':   cap.titulo,
        'titulo':     widget.titulo,
      },
    );
  }

  // =========================================================
  // BARRA NAVEGAÇÃO CAPÍTULOS
  // =========================================================

  Widget _buildNavCapitulos(bool isDark, Color roxo) {
    final temAnterior = _capituloAnterior != null;
    final temProximo  = _proximoCapitulo != null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1030) : Colors.white,
        border:
            Border(bottom: BorderSide(color: roxo.withOpacity(0.15))),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 6,
              offset: const Offset(0, 2))
        ],
      ),
      child: Row(children: [
        Expanded(
          child: temAnterior
              ? _navBtn(
                  label: 'Cap. ${_capituloAnterior!.numero}',
                  icon: Icons.arrow_back_ios_rounded,
                  iconAtStart: true,
                  roxo: roxo,
                  isDark: isDark,
                  onTap: () => _irParaCapitulo(_capituloAnterior!),
                )
              : const SizedBox(),
        ),
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: roxo.withOpacity(0.10),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            _capitulos.isNotEmpty
                ? 'Cap. ${_capitulos.firstWhere((c) => c.id == widget.capituloId, orElse: () => _capitulos.first).numero}'
                : widget.capitulo,
            style: TextStyle(
                color: roxo,
                fontWeight: FontWeight.w800,
                fontSize: 13),
          ),
        ),
        Expanded(
          child: temProximo
              ? _navBtn(
                  label: 'Cap. ${_proximoCapitulo!.numero}',
                  icon: Icons.arrow_forward_ios_rounded,
                  iconAtStart: false,
                  roxo: roxo,
                  isDark: isDark,
                  onTap: () => _irParaCapitulo(_proximoCapitulo!),
                )
              : const SizedBox(),
        ),
      ]),
    );
  }

  Widget _navBtn({
    required String label,
    required IconData icon,
    required bool iconAtStart,
    required Color roxo,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    final children = iconAtStart
        ? <Widget>[
            Icon(icon, size: 14, color: roxo),
            const SizedBox(width: 4),
            Text(label),
          ]
        : <Widget>[
            Text(label),
            const SizedBox(width: 4),
            Icon(icon, size: 14, color: roxo),
          ];

    return Align(
      alignment:
          iconAtStart ? Alignment.centerLeft : Alignment.centerRight,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: roxo.withOpacity(0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: roxo.withOpacity(0.20)),
          ),
          child: DefaultTextStyle(
            style: TextStyle(
                color: roxo,
                fontWeight: FontWeight.w700,
                fontSize: 12),
            child:
                Row(mainAxisSize: MainAxisSize.min, children: children),
          ),
        ),
      ),
    );
  }

  // =========================================================
  // WIDGET COMENTÁRIOS
  // =========================================================

  Widget comentariosWidget() {
    final roxo   = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      color: isDark ? const Color(0xFF140F1F) : Colors.white,
      child: Column(children: [
        const SizedBox(height: 12),
        Container(
          width: 60,
          height: 4,
          decoration: BoxDecoration(
            color: roxo.withOpacity(0.35),
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        const SizedBox(height: 14),

        // Botão próximo capítulo
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _proximoCapitulo != null
              ? SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () =>
                        _irParaCapitulo(_proximoCapitulo!),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: roxo,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding:
                          const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                    icon: const Icon(Icons.arrow_forward_rounded),
                    label: Text(
                      'Próximo: ${_proximoCapitulo!.titulo}',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                )
              : Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: roxo.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle_rounded,
                            color: roxo, size: 20),
                        const SizedBox(width: 8),
                        Text('Último capítulo disponível',
                            style: TextStyle(
                                color: roxo,
                                fontWeight: FontWeight.w700)),
                      ]),
                ),
        ),

        const SizedBox(height: 20),

        Text('Comentários',
            style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: roxo)),
        const SizedBox(height: 12),

        // Campo de novo comentário
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: TextField(
            controller: comentarioController,
            style: TextStyle(
                color: isDark ? Colors.white : Colors.black87),
            maxLines: null,
            decoration: InputDecoration(
              hintText: 'Digite um comentário...',
              hintStyle: TextStyle(
                  color: isDark ? Colors.white38 : Colors.black38),
              suffixIcon: _enviandoComentario
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2)),
                    )
                  : IconButton(
                      icon: Icon(Icons.send_rounded, color: roxo),
                      onPressed: _adicionarComentario,
                    ),
              filled: true,
              fillColor: isDark
                  ? const Color(0xFF231840)
                  : const Color(0xFFF5F3FF),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 12),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: roxo, width: 1.2)),
            ),
          ),
        ),
        const SizedBox(height: 8),

        // Lista de comentários
        if (_carregandoComentarios)
          Padding(
            padding: const EdgeInsets.all(24),
            child: CircularProgressIndicator(color: roxo),
          )
        else if (_comentarios.isEmpty)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Nenhum comentário ainda. Seja o primeiro!',
              style: TextStyle(
                  color: isDark ? Colors.white38 : Colors.black38),
            ),
          )
        else
          ..._comentarios.map((comentario) {
            final eMeu = _eMeuComentario(comentario);
            final nomeUsuario =
                comentario['usuarios']?['nome'] ?? 'Usuário';
            return Container(
              margin: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF20172C)
                    : const Color(0xFFF7F2FF),
                borderRadius: BorderRadius.circular(16),
                border:
                    Border.all(color: roxo.withOpacity(0.10)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Cabeçalho: nome + hora + botões
                    Row(children: [
                      Text(
                        nomeUsuario,
                        style: TextStyle(
                            color: roxo,
                            fontWeight: FontWeight.w800,
                            fontSize: 13),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatarData(
                            comentario['criado_em'] ?? ''),
                        style: TextStyle(
                            fontSize: 11,
                            color: isDark
                                ? Colors.white38
                                : Colors.black38),
                      ),
                      if (comentario['editado'] == 1 ||
                          comentario['editado'] == true)
                        Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: Text(
                            '(editado)',
                            style: TextStyle(
                                fontSize: 10,
                                color: isDark
                                    ? Colors.white38
                                    : Colors.black38),
                          ),
                        ),
                      const Spacer(),
                      if (eMeu) ...[
                        GestureDetector(
                          onTap: () =>
                              _editarComentario(comentario),
                          child: Icon(Icons.edit_rounded,
                              color: roxo, size: 18),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () =>
                              _excluirComentario(comentario),
                          child: const Icon(
                              Icons.delete_rounded,
                              color: Colors.redAccent,
                              size: 18),
                        ),
                      ],
                    ]),
                    const SizedBox(height: 6),
                    // Conteúdo
                    Text(
                      comentario['conteudo'],
                      style: TextStyle(
                          fontSize: 14,
                          height: 1.4,
                          color: isDark
                              ? Colors.white
                              : Colors.black87),
                    ),
                  ],
                ),
              ),
            );
          }),

        const SizedBox(height: 24),
      ]),
    );
  }

  // =========================================================
  // BUILD
  // =========================================================

  @override
  Widget build(BuildContext context) {
    if (_carregando || controller == null) {
      return const Scaffold(
          body: Center(child: CircularProgressIndicator()));
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final roxo =
        isDark ? const Color(0xFF9F67FA) : const Color(0xFF7C3AED);

    return Scaffold(
      backgroundColor:
          isDark ? Colors.black : const Color(0xFFF7F4FB),
      appBar: AppBar(
        backgroundColor:
            isDark ? const Color(0xFF1A1030) : roxo,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(widget.capitulo,
            style: const TextStyle(fontWeight: FontWeight.w700)),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Voltar',
            icon: const Icon(Icons.home_rounded),
            onPressed: () => Navigator.pop(context),
          ),
          IconButton(
            tooltip: modoClique ? 'Modo rolagem' : 'Modo toque',
            icon: Icon(modoClique
                ? Icons.swipe_rounded
                : Icons.touch_app_rounded),
            onPressed: () =>
                _safeSetState(() => modoClique = !modoClique),
          ),
        ],
      ),
      body: Column(children: [
        _buildNavCapitulos(isDark, roxo),
        Expanded(
          child: modoClique
              ? PageView.builder(
                  controller: controller,
                  itemCount: _paginas.length + 1,
                  onPageChanged: (index) async {
                    if (index < _paginas.length) {
                      _paginaAtual = index + 1;
                      await _marcarConcluidoSeNecessario(index);
                    }
                  },
                  itemBuilder: (context, index) {
                    if (index < _paginas.length) {
                      return _buildPaginaClique(index, isDark);
                    }
                    return SingleChildScrollView(
                        child: comentariosWidget());
                  },
                )
              : ListView.builder(
                  itemCount: _paginas.length + 1,
                  itemBuilder: (context, index) {
                    if (index < _paginas.length) {
                      return _buildPaginaRolagem(index, isDark);
                    }
                    return comentariosWidget();
                  },
                ),
        ),
      ]),
    );
  }

  // =========================================================
  // HELPERS DE IMAGEM
  // =========================================================

  Widget _buildPaginaClique(int index, bool isDark) {
    final pagina = _paginas[index];
    return GestureDetector(
      onTapUp: (details) {
        final largura = MediaQuery.of(context).size.width;
        final posicao = details.localPosition.dx;
        if (posicao > largura / 2) {
          if (index < _paginas.length - 1) {
            controller!.nextPage(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut);
          }
        } else {
          if (index > 0) {
            controller!.previousPage(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut);
          }
        }
      },
      child: Container(
        color: isDark ? Colors.black : const Color(0xFFF2F2F2),
        child: Center(
          child: InteractiveViewer(
            minScale: 1,
            maxScale: 4,
            child: _buildImagem(pagina),
          ),
        ),
      ),
    );
  }

  Widget _buildPaginaRolagem(int index, bool isDark) {
    final pagina = _paginas[index];
    return Container(
      color: isDark ? Colors.black : const Color(0xFFF2F2F2),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: _buildImagem(pagina),
      ),
    );
  }

  Widget _buildImagem(Pagina pagina) {
    if (pagina.imagemLocal != null && pagina.imagemLocal!.isNotEmpty) {
      return Image.file(File(pagina.imagemLocal!),
          fit: BoxFit.fitWidth,
          errorBuilder: (_, __, ___) =>
              const Center(child: Text('Erro ao carregar página')));
    }
    return Image.network(pagina.imagemUrl,
        fit: BoxFit.fitWidth,
        errorBuilder: (_, __, ___) =>
            const Center(child: Text('Erro ao carregar página')));
  }
}