import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

import 'package:toonarchive/app/modules/progresso/progresso_repository.dart';
import 'package:toonarchive/app/modules/paginas/paginas_repository.dart';
import 'package:toonarchive/app/modules/capitulos/capitulos_repository.dart';
import 'package:toonarchive/app/core/services/auth_service.dart';
import 'package:toonarchive/app/core/database/database_helper.dart';
import 'package:toonarchive/app/core/helpers/app.config.dart';
import 'package:toonarchive/app/modules/paginas/pagina.dart';
import 'package:toonarchive/app/modules/capitulos/capitulo.dart';
import 'package:toonarchive/app/modules/usuarios/usuario.dart';

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

class _LeituraPageState extends State<LeituraPage> with WidgetsBindingObserver {
  bool _disposed = false;
  bool modoClique = false;
  bool _modoOffline = false;
  bool _capituloDisponivelOffline = false;
  bool _naSecaoComentarios = false;

  PageController? controller;

  String? _usuarioId;
  String? _obraId;
  Usuario? _usuario;

  final _paginasRepo = PaginasRepository.instance;
  final _progressoRepo = ProgressoRepository.instance;
  final _authService = AuthService();
  final _capitulosRepo = CapitulosRepository.instance;
  final _supabase = Supabase.instance.client;
  final _picker = ImagePicker();

  final TextEditingController comentarioController = TextEditingController();
  final TextEditingController _gifController = TextEditingController();

  List<Pagina> _paginas = [];
  List<Capitulo> _capitulos = [];
  List<Map<String, dynamic>> _comentarios = [];

  bool _carregando = true;
  bool _carregandoComentarios = false;
  bool _enviandoComentario = false;
  int _paginaAtual = 1;

  // ── painéis mídia nos comentários ─────────────────────────
  bool _mostrarEmoji = false;
  bool _mostrarMidia = false;

  // ── GIFs ──────────────────────────────────────────────────
  List<Map<String, dynamic>> _gifs = [];
  final _gifFocusNode = FocusNode();
  bool _gifFieldFocado = false;
  bool _carregandoGifs = false;

  // ── Stickers fixos ────────────────────────────────────────
  final List<String> _stickers = [
    'https://media.giphy.com/media/xT9IgG50Lg7russbD6/giphy.gif',
    'https://media.giphy.com/media/3oEjI6SIIHBdRxXI40/giphy.gif',
    'https://media.giphy.com/media/l0MYt5jPR6QX5pnqM/giphy.gif',
    'https://media.giphy.com/media/26ufdipQqU2lhNA4g/giphy.gif',
    'https://media.giphy.com/media/3oz8xIsloV7zOmt81G/giphy.gif',
    'https://media.giphy.com/media/xT5LMHxhOfscxPfIfm/giphy.gif',
  ];

  Capitulo? _capituloAnterior;
  Capitulo? _proximoCapitulo;
  bool _progressoSalvo = false;

  // =========================================================
  // LIFECYCLE
  // =========================================================

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _gifFocusNode.addListener(() {
      _gifFieldFocado = _gifFocusNode.hasFocus;
    });
    _inicializar();
  }

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _salvarProgressoUmaVez();
    controller?.dispose();
    comentarioController.dispose();
    _gifController.dispose();
    _gifFocusNode.dispose();
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

  Future<bool> _online() async {
    final result = await Connectivity().checkConnectivity();
    return result.any((r) => r != ConnectivityResult.none);
  }

  // =========================================================
  // INICIALIZAÇÃO
  // =========================================================

  Future<void> _inicializar() async {
    final usuario = await _authService.getUsuarioInterno();
    if (_disposed) return;
    _usuario = usuario;
    _usuarioId = usuario?.id;
    _obraId = widget.obraId;

    final online = await _online();
    _modoOffline = !online;

    final rows = await DatabaseHelper.instance.query(
      'capitulos',
      where: 'id = ? AND disponivel_offline = 1',
      whereArgs: [widget.capituloId],
    );
    if (_disposed) return;
    _capituloDisponivelOffline = rows.isNotEmpty;

    await _carregarPaginas(online: online);
    if (_disposed) return;
    await _carregarCapitulos();
    if (_disposed) return;
    await _carregarProgresso();
    if (online) await _carregarComentarios();
  }

  // =========================================================
  // PÁGINAS / CAPÍTULOS / PROGRESSO
  // =========================================================

  Future<void> _carregarPaginas({bool online = true}) async {
    if (!online) {
      if (!_capituloDisponivelOffline) {
        if (_disposed) return;
        _safeSetState(() => _paginas = []);
        return;
      }
      final paginas =
          await _paginasRepo.listarPaginasBaixadas(widget.capituloId);
      if (_disposed) return;
      _safeSetState(() => _paginas = paginas);
      return;
    }
    try {
      final paginas =
          await _paginasRepo.listarParaLeituraOnline(widget.capituloId);
      if (_disposed) return;
      _safeSetState(() => _paginas = paginas);
    } catch (_) {
      final paginas =
          await _paginasRepo.listarPaginasBaixadas(widget.capituloId);
      if (_disposed) return;
      _safeSetState(() => _paginas = paginas);
    }
  }

  Future<void> _carregarCapitulos() async {
    final lista = await _capitulosRepo.listarPorObra(widget.obraId);
    if (_disposed) return;
    lista.sort((a, b) => a.numero.compareTo(b.numero));
    final indexAtual = lista.indexWhere((c) => c.id == widget.capituloId);
    _safeSetState(() {
      _capitulos = lista;
      _capituloAnterior = indexAtual > 0 ? lista[indexAtual - 1] : null;
      _proximoCapitulo = (indexAtual != -1 && indexAtual < lista.length - 1)
          ? lista[indexAtual + 1]
          : null;
    });
  }

  Future<void> _carregarProgresso() async {
    if (_usuarioId == null || _obraId == null) {
      _inicializarController();
      return;
    }
    final progresso =
        await _progressoRepo.buscarProgresso(_usuarioId!, _obraId!);
    if (_disposed) return;
    if (progresso != null && progresso.capituloId == widget.capituloId) {
      _paginaAtual = progresso.ultimaPagina;
    }
    _inicializarController();
  }

  void _inicializarController() {
    if (_disposed) return;
    controller?.dispose();
    controller =
        PageController(initialPage: _paginaAtual > 0 ? _paginaAtual - 1 : 0);
    _safeSetState(() => _carregando = false);
  }

  Future<void> _salvarProgresso() async {
    if (_usuarioId == null || _obraId == null) return;
    try {
      await _progressoRepo.salvarProgresso(
        usuarioId: _usuarioId!,
        obraId: _obraId!,
        capituloId: widget.capituloId,
        ultimaPagina: _paginaAtual,
      );
    } catch (_) {}
  }

  Future<void> _marcarConcluidoSeNecessario(int indexPagina) async {
    if (_usuarioId == null || _obraId == null) return;
    if (indexPagina == _paginas.length - 1) {
      try {
        await _progressoRepo.marcarConcluido(
          usuarioId: _usuarioId!,
          obraId: _obraId!,
          capituloId: widget.capituloId,
        );
      } catch (_) {}
    }
  }

  // =========================================================
  // COMENTÁRIOS — texto
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
      // Fallback sem join se a FK não existir no Supabase
      try {
        final rows = await _supabase
            .from('comentarios')
            .select()
            .eq('obra_id', widget.obraId)
            .eq('capitulo_id', widget.capituloId)
            .order('criado_em', ascending: true);

        if (_disposed) return;
        _safeSetState(() {
          _comentarios = List<Map<String, dynamic>>.from(rows);
          _carregandoComentarios = false;
        });
      } catch (_) {
        if (_disposed) return;
        _safeSetState(() => _carregandoComentarios = false);
      }
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

    _safeSetState(() {
      _enviandoComentario = true;
      _mostrarEmoji = false;
    });
    comentarioController.clear();

    // Garante que o usuário existe no Supabase antes de inserir o comentário.
    // Necessário para contas Google cujo upsert pode ter falhado silenciosamente.
    await _authService.garantirUsuarioNoSupabase(_usuario!);

    try {
      await _supabase.from('comentarios').insert({
        'usuario_id': _usuario!.id,
        'obra_id': widget.obraId,
        'capitulo_id': widget.capituloId,
        'conteudo': texto,
      });
      await _carregarComentarios();
    } catch (e) {
      if (_disposed) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Erro ao comentar: $e')));
    } finally {
      if (mounted) _safeSetState(() => _enviandoComentario = false);
    }
  }

  // ── Enviar mídia (gif / sticker / imagem) ─────────────────
  Future<void> _enviarMidiaComentario({
    required String tipo,
    required String conteudo,
    required String? mediaUrl,
  }) async {
    if (_usuario == null) return;
    _safeSetState(() => _enviandoComentario = true);
    await _authService.garantirUsuarioNoSupabase(_usuario!);
    try {
      final row = await _supabase
          .from('comentarios')
          .insert({
            'usuario_id': _usuario!.id,
            'obra_id': widget.obraId,
            'capitulo_id': widget.capituloId,
            'conteudo': conteudo,
            'tipo': tipo,
            'media_url': mediaUrl,
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
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Erro ao enviar mídia: $e')));
    }
  }

  // ── Upload de foto ─────────────────────────────────────────
  Future<void> _enviarFoto({bool camera = false}) async {
    _safeSetState(() => _mostrarMidia = false);
    final xfile = await _picker.pickImage(
      source: camera ? ImageSource.camera : ImageSource.gallery,
      imageQuality: 70,
      maxWidth: 1200,
    );
    if (xfile == null) return;

    _safeSetState(() => _enviandoComentario = true);
    try {
      final bytes = await xfile.readAsBytes();
      final ext = xfile.path.split('.').last;
      final path =
          'comentarios/${widget.obraId}/${_usuario!.id}_${DateTime.now().millisecondsSinceEpoch}.$ext';

      await _supabase.storage.from('chat-media').uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(contentType: 'image/$ext'),
          );

      final url = _supabase.storage.from('chat-media').getPublicUrl(path);
      await _enviarMidiaComentario(
          tipo: 'imagem', conteudo: '📷 Foto', mediaUrl: url);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Erro no upload: $e')));
    } finally {
      if (mounted) _safeSetState(() => _enviandoComentario = false);
    }
  }

  // ── Buscar GIFs (Giphy) ────────────────────────────────────
  Future<void> _buscarGifs(String query) async {
    _safeSetState(() => _carregandoGifs = true);
    try {
      final endpoint = query.isEmpty
          ? 'https://api.giphy.com/v1/gifs/trending'
          : 'https://api.giphy.com/v1/gifs/search';
      final uri = Uri.parse(endpoint).replace(queryParameters: {
        'api_key': AppConfig.giphyApiKey,
        'limit': '20',
        'rating': 'g',
        if (query.isNotEmpty) 'q': query,
      });
      final resp = await http.get(uri);
      final json = jsonDecode(resp.body);
      final data = json['data'] as List;
      _safeSetState(() {
        _gifs = data
            .map((g) => {
                  'preview': g['images']['fixed_height_small']['url'] as String,
                  'url': g['images']['original']['url'] as String,
                })
            .toList();
        _carregandoGifs = false;
      });
    } catch (_) {
      _safeSetState(() => _carregandoGifs = false);
    }
  }

  // ── Editar / Excluir ───────────────────────────────────────
  Future<void> _editarComentario(Map<String, dynamic> comentario) async {
    comentarioController.text = comentario['conteudo'];
    final salvar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Editar comentário'),
        content: TextField(
            controller: comentarioController, autofocus: true, maxLines: null),
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
      await _supabase.from('comentarios').update({
        'conteudo': comentarioController.text.trim(),
        'editado': 1,
        'atualizado_em': DateTime.now().toIso8601String(),
      }).eq('id', comentario['id']);

      if (_disposed) return;
      _safeSetState(() {
        final i = _comentarios.indexWhere((c) => c['id'] == comentario['id']);
        if (i != -1) {
          _comentarios[i]['conteudo'] = comentarioController.text.trim();
          _comentarios[i]['editado'] = 1;
        }
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Erro ao editar: $e')));
    }
    comentarioController.clear();
  }

  Future<void> _excluirComentario(Map<String, dynamic> comentario) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Excluir comentário'),
        content: const Text('Tem certeza que deseja excluir este comentário?'),
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
      await _supabase.from('comentarios').delete().eq('id', comentario['id']);
      if (_disposed) return;
      _safeSetState(
          () => _comentarios.removeWhere((c) => c['id'] == comentario['id']));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Erro ao excluir: $e')));
    }
  }

  bool _eMeuComentario(Map<String, dynamic> c) =>
      c['usuario_id'] == _usuario?.id || _usuario?.role == 'admin';

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
        'obraId': widget.obraId,
        'capituloId': cap.id,
        'capitulo': cap.titulo,
        'titulo': widget.titulo,
      },
    );
  }

  // =========================================================
  // BARRA NAVEGAÇÃO CAPÍTULOS
  // =========================================================

  Widget _buildNavCapitulos(bool isDark, Color roxo) {
    final temAnterior = _capituloAnterior != null;
    final temProximo = _proximoCapitulo != null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1030) : Colors.white,
        border: Border(bottom: BorderSide(color: roxo.withOpacity(0.15))),
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
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: roxo.withOpacity(0.10),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            _capitulos.isNotEmpty
                ? 'Cap. ${_capitulos.firstWhere((c) => c.id == widget.capituloId, orElse: () => _capitulos.first).numero}'
                : widget.capitulo,
            style: TextStyle(
                color: roxo, fontWeight: FontWeight.w800, fontSize: 13),
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
      alignment: iconAtStart ? Alignment.centerLeft : Alignment.centerRight,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: roxo.withOpacity(0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: roxo.withOpacity(0.20)),
          ),
          child: DefaultTextStyle(
            style: TextStyle(
                color: roxo, fontWeight: FontWeight.w700, fontSize: 12),
            child: Row(mainAxisSize: MainAxisSize.min, children: children),
          ),
        ),
      ),
    );
  }

  // =========================================================
  // WIDGET COMENTÁRIOS
  // =========================================================

  Widget comentariosWidget() {
    final roxo = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 80,
      ),
      child: Container(
        color: isDark ? const Color(0xFF140F1F) : Colors.white,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 12),
            Center(
              child: Container(
                width: 60,
                height: 4,
                decoration: BoxDecoration(
                  color: roxo.withOpacity(0.35),
                  borderRadius: BorderRadius.circular(999),
                ),
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
                        onPressed: () => _irParaCapitulo(_proximoCapitulo!),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: roxo,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                        ),
                        icon: const Icon(Icons.arrow_forward_rounded),
                        label: Text('Próximo: ${_proximoCapitulo!.titulo}',
                            style:
                                const TextStyle(fontWeight: FontWeight.w700)),
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
                                  color: roxo, fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
            ),
            const SizedBox(height: 20),

            Center(
              child: Text('Comentários',
                  style: TextStyle(
                      fontSize: 19, fontWeight: FontWeight.w800, color: roxo)),
            ),
            const SizedBox(height: 12),

            if (_carregandoComentarios)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_modoOffline)
              Padding(
                padding: const EdgeInsets.all(24),
                child:
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.wifi_off_rounded,
                      color: isDark ? Colors.white38 : Colors.black38,
                      size: 18),
                  const SizedBox(width: 8),
                  Text('Comentários indisponíveis offline.',
                      style: TextStyle(
                          color: isDark ? Colors.white38 : Colors.black38)),
                ]),
              )
            else if (_comentarios.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: Text(
                    'Nenhum comentário ainda. Seja o primeiro!',
                    style: TextStyle(
                        color: isDark ? Colors.white38 : Colors.black38),
                  ),
                ),
              )
            else
              ..._comentarios.map((comentario) {
                final eMeu = _eMeuComentario(comentario);
                final nomeUsuario =
                    comentario['usuarios']?['nome'] ?? 'Usuário';
                final tipo = comentario['tipo'] as String? ?? 'texto';
                final eMidia =
                    tipo == 'imagem' || tipo == 'gif' || tipo == 'sticker';

                return Container(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF20172C)
                        : const Color(0xFFF7F2FF),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: roxo.withOpacity(0.10)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Text(nomeUsuario,
                              style: TextStyle(
                                  color: roxo,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13)),
                          const SizedBox(width: 8),
                          Text(
                            _formatarData(comentario['criado_em'] ?? ''),
                            style: TextStyle(
                                fontSize: 11,
                                color:
                                    isDark ? Colors.white38 : Colors.black38),
                          ),
                          if (comentario['editado'] == 1 ||
                              comentario['editado'] == true)
                            Padding(
                              padding: const EdgeInsets.only(left: 4),
                              child: Text('(editado)',
                                  style: TextStyle(
                                      fontSize: 10,
                                      color: isDark
                                          ? Colors.white38
                                          : Colors.black38)),
                            ),
                          const Spacer(),
                          if (eMeu) ...[
                            if (!eMidia)
                              GestureDetector(
                                onTap: () => _editarComentario(comentario),
                                child: Icon(Icons.edit_rounded,
                                    color: roxo, size: 18),
                              ),
                            if (!eMidia) const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () => _excluirComentario(comentario),
                              child: const Icon(Icons.delete_rounded,
                                  color: Colors.redAccent, size: 18),
                            ),
                          ],
                        ]),
                        const SizedBox(height: 6),
                        if (eMidia && comentario['media_url'] != null)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.network(
                              comentario['media_url'],
                              width: tipo == 'sticker' ? 100 : double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Icon(
                                  Icons.broken_image_rounded,
                                  size: 40,
                                  color: Colors.grey),
                            ),
                          )
                        else
                          Text(
                            comentario['conteudo'] ?? '',
                            style: TextStyle(
                                fontSize: 14,
                                height: 1.4,
                                color: isDark ? Colors.white : Colors.black87),
                          ),
                      ],
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  // Input fixo — renderizado como bottomNavigationBar do Scaffold principal
  Widget _inputComentario(bool isDark, Color roxo) {
    return Container(
      color: isDark ? const Color(0xFF1A1030) : Colors.white,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Divider(height: 1, color: roxo.withOpacity(0.12)),
          if (_mostrarEmoji)
            SizedBox(
              height: 260,
              child: EmojiPicker(
                onEmojiSelected: (_, emoji) {
                  comentarioController.text += emoji.emoji;
                  comentarioController.selection = TextSelection.fromPosition(
                      TextPosition(offset: comentarioController.text.length));
                },
                config: Config(
                  height: 260,
                  emojiViewConfig: EmojiViewConfig(
                    backgroundColor:
                        isDark ? const Color(0xFF1A1030) : Colors.white,
                  ),
                  categoryViewConfig: CategoryViewConfig(
                    backgroundColor:
                        isDark ? const Color(0xFF1A1030) : Colors.white,
                    iconColor: isDark ? Colors.white38 : Colors.black38,
                    iconColorSelected: roxo,
                    indicatorColor: roxo,
                  ),
                ),
              ),
            ),
          if (_mostrarMidia) _buildPainelMidia(isDark, roxo),
          if (_modoOffline)
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF231840)
                        : const Color(0xFFF5F3FF),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(children: [
                    Icon(Icons.wifi_off_rounded,
                        size: 16,
                        color: isDark ? Colors.white38 : Colors.black38),
                    const SizedBox(width: 8),
                    Text('Sem conexão para comentar',
                        style: TextStyle(
                            color: isDark ? Colors.white38 : Colors.black38,
                            fontSize: 13)),
                  ]),
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
              child: Row(children: [
                IconButton(
                  icon: Icon(
                    _mostrarEmoji
                        ? Icons.keyboard_rounded
                        : Icons.emoji_emotions_rounded,
                    color: roxo,
                  ),
                  onPressed: () async {
                    FocusScope.of(context).unfocus();
                    await Future.delayed(const Duration(milliseconds: 150));
                    if (!mounted) return;
                    _safeSetState(() {
                      _mostrarEmoji = !_mostrarEmoji;
                      if (_mostrarEmoji) _mostrarMidia = false;
                    });
                  },
                ),
                Expanded(
                  child: TextField(
                    controller: comentarioController,
                    style: TextStyle(
                        color: isDark ? Colors.white : Colors.black87),
                    maxLines: null,
                    onTap: () => _safeSetState(() {
                      _mostrarEmoji = false;
                      _mostrarMidia = false;
                    }),
                    decoration: InputDecoration(
                      hintText: 'Digite um comentário...',
                      hintStyle: TextStyle(
                          color: isDark ? Colors.white38 : Colors.black38),
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
                IconButton(
                  icon: Icon(
                    _mostrarMidia
                        ? Icons.close_rounded
                        : Icons.add_circle_rounded,
                    color: roxo,
                  ),
                  onPressed: () async {
                    FocusScope.of(context).unfocus();
                    await Future.delayed(const Duration(milliseconds: 150));
                    if (!mounted) return;
                    _safeSetState(() {
                      _mostrarMidia = !_mostrarMidia;
                      if (_mostrarMidia) _mostrarEmoji = false;
                    });
                  },
                ),
                GestureDetector(
                  onTap: _enviandoComentario ? null : _adicionarComentario,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                          colors: [roxo, const Color(0xFF9F67FA)]),
                      shape: BoxShape.circle,
                    ),
                    child: _enviandoComentario
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.send_rounded,
                            color: Colors.white, size: 18),
                  ),
                ),
              ]),
            ),
        ],
      ),
    );
  }

  // =========================================================
  // PAINEL MÍDIA (GIF / Sticker / Foto)
  // =========================================================

  Widget _buildPainelMidia(bool isDark, Color roxo) {
    return Container(
      height: 320,
      color: isDark ? const Color(0xFF1A1030) : Colors.white,
      child: DefaultTabController(
        length: 3,
        child: Column(children: [
          TabBar(
            indicatorColor: roxo,
            labelColor: roxo,
            unselectedLabelColor: isDark ? Colors.white38 : Colors.black38,
            tabs: const [
              Tab(icon: Icon(Icons.gif_box_rounded), text: 'GIFs'),
              Tab(icon: Icon(Icons.emoji_emotions_rounded), text: 'Stickers'),
              Tab(icon: Icon(Icons.photo_rounded), text: 'Foto'),
            ],
          ),
          Expanded(
            child: TabBarView(children: [
              // ── GIFs ──────────────────────────────────
              Column(children: [
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: TextField(
                    controller: _gifController,
                    focusNode: _gifFocusNode,
                    onSubmitted: _buscarGifs,
                    style: TextStyle(
                        color: isDark ? Colors.white : Colors.black87),
                    decoration: InputDecoration(
                      hintText: 'Buscar GIF...',
                      prefixIcon: Icon(Icons.search_rounded, color: roxo),
                      suffixIcon: IconButton(
                        icon: Icon(Icons.send_rounded, color: roxo),
                        onPressed: () => _buscarGifs(_gifController.text),
                      ),
                      filled: true,
                      fillColor: isDark
                          ? const Color(0xFF231840)
                          : const Color(0xFFF5F3FF),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none),
                    ),
                  ),
                ),
                Expanded(
                  child: _carregandoGifs
                      ? Center(child: CircularProgressIndicator(color: roxo))
                      : _gifs.isEmpty
                          ? Center(
                              child: ElevatedButton.icon(
                                onPressed: () => _buscarGifs(''),
                                icon: const Icon(Icons.trending_up_rounded),
                                label: const Text('Ver trending'),
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: roxo,
                                    foregroundColor: Colors.white),
                              ),
                            )
                          : GridView.builder(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8),
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 3,
                                      crossAxisSpacing: 4,
                                      mainAxisSpacing: 4),
                              itemCount: _gifs.length,
                              itemBuilder: (_, i) => GestureDetector(
                                onTap: () async {
                                  _safeSetState(() => _mostrarMidia = false);
                                  await _enviarMidiaComentario(
                                    tipo: 'gif',
                                    conteudo: '🎞️ GIF',
                                    mediaUrl: _gifs[i]['url'],
                                  );
                                },
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    _gifs[i]['preview'],
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) =>
                                        Container(color: roxo.withOpacity(0.1)),
                                  ),
                                ),
                              ),
                            ),
                ),
              ]),

              // ── Stickers ──────────────────────────────
              GridView.builder(
                padding: const EdgeInsets.all(8),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3, crossAxisSpacing: 6, mainAxisSpacing: 6),
                itemCount: _stickers.length,
                itemBuilder: (_, i) => GestureDetector(
                  onTap: () async {
                    _safeSetState(() => _mostrarMidia = false);
                    await _enviarMidiaComentario(
                      tipo: 'sticker',
                      conteudo: '🪄 Sticker',
                      mediaUrl: _stickers[i],
                    );
                  },
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(_stickers[i],
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                            color: roxo.withOpacity(0.1),
                            child:
                                Icon(Icons.broken_image_rounded, color: roxo))),
                  ),
                ),
              ),

              // ── Foto ──────────────────────────────────
              Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _botaoFoto(
                          icon: Icons.photo_library_rounded,
                          label: 'Galeria',
                          roxo: roxo,
                          onTap: () => _enviarFoto()),
                      _botaoFoto(
                          icon: Icons.camera_alt_rounded,
                          label: 'Câmera',
                          roxo: roxo,
                          onTap: () => _enviarFoto(camera: true)),
                    ]),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _botaoFoto({
    required IconData icon,
    required String label,
    required Color roxo,
    required VoidCallback onTap,
  }) =>
      GestureDetector(
        onTap: onTap,
        child: Column(children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: roxo.withOpacity(0.12),
              shape: BoxShape.circle,
              border: Border.all(color: roxo.withOpacity(0.3)),
            ),
            child: Icon(icon, color: roxo, size: 32),
          ),
          const SizedBox(height: 8),
          Text(label,
              style: TextStyle(color: roxo, fontWeight: FontWeight.w700)),
        ]),
      );

  // =========================================================
  // BUILD PRINCIPAL
  // =========================================================

  @override
  Widget build(BuildContext context) {
    if (_carregando || controller == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final roxo = isDark ? const Color(0xFF9F67FA) : const Color(0xFF7C3AED);

    if (_modoOffline && !_capituloDisponivelOffline) {
      return _buildBloqueioOffline(isDark, roxo);
    }

    return Scaffold(
      backgroundColor: isDark ? Colors.black : const Color(0xFFF7F4FB),
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1A1030) : roxo,
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
            icon: Icon(
                modoClique ? Icons.swipe_rounded : Icons.touch_app_rounded),
            onPressed: () => _safeSetState(() => modoClique = !modoClique),
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(children: [
            _buildNavCapitulos(isDark, roxo),
            Expanded(
              child: modoClique
                  ? PageView.builder(
                      controller: controller,
                      itemCount: _paginas.length + 1,
                      onPageChanged: (index) {
                        _safeSetState(() =>
                            _naSecaoComentarios = index == _paginas.length);
                        if (index < _paginas.length) {
                          _paginaAtual = index + 1;
                          _marcarConcluidoSeNecessario(index);
                        }
                      },
                      itemBuilder: (context, index) {
                        if (index < _paginas.length) {
                          return _buildPaginaClique(index, isDark);
                        }
                        // Modo clique: página de comentários auto-contida com input fixo
                        return _comentariosPageFull(isDark, roxo);
                      },
                    )
                  : NotificationListener<ScrollNotification>(
                      onNotification: (n) {
                        if (n is ScrollUpdateNotification) {
                          final atBottom = n.metrics.pixels >=
                              n.metrics.maxScrollExtent - 200;
                          if (atBottom != _naSecaoComentarios) {
                            _safeSetState(() => _naSecaoComentarios = atBottom);
                          }
                        }
                        return false;
                      },
                      child: ListView.builder(
                        itemCount: _paginas.length + 1,
                        itemBuilder: (context, index) {
                          if (index < _paginas.length) {
                            return _buildPaginaRolagem(index, isDark);
                          }
                          // Modo rolagem: comentários com espaço pro input flutuante
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 80),
                            child: comentariosWidget(),
                          );
                        },
                      ),
                    ),
            ),
          ]),

          // Modo rolagem: input flutua no fundo quando na seção de comentários
          if (!modoClique && _naSecaoComentarios)
            Positioned(
              bottom: MediaQuery.of(context).viewInsets.bottom,
              left: 0,
              right: 0,
              child: SafeArea(
                top: false,
                child: _inputComentario(isDark, roxo),
              ),
            ),
        ],
      ),
    );
  }

  Widget _comentariosPageFull(bool isDark, Color roxo) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 8),
            child: comentariosWidget(),
          ),
        ),
        _inputComentario(isDark, roxo),
      ],
    );
  }

  @override
  void didChangeMetrics() {
    final bottomInset = WidgetsBinding
        .instance.platformDispatcher.views.first.viewInsets.bottom;
    if (bottomInset > 100 &&
        (_mostrarEmoji || _mostrarMidia) &&
        !_gifFieldFocado) {
      _safeSetState(() {
        _mostrarEmoji = false;
        _mostrarMidia = false;
      });
    }
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
    final localPath = pagina.imagemLocal;
    if (localPath != null && localPath.isNotEmpty) {
      return Image.file(
        File(localPath),
        fit: BoxFit.fitWidth,
        errorBuilder: (_, __, ___) => _erroImagem(),
      );
    }
    return Image.network(
      pagina.imagemUrl,
      fit: BoxFit.fitWidth,
      loadingBuilder: (_, child, progress) {
        if (progress == null) return child;
        return SizedBox(
          height: 300,
          child: Center(
            child: CircularProgressIndicator(
              value: progress.expectedTotalBytes != null
                  ? progress.cumulativeBytesLoaded /
                      progress.expectedTotalBytes!
                  : null,
              strokeWidth: 2,
            ),
          ),
        );
      },
      errorBuilder: (_, __, ___) => _erroImagem(),
    );
  }

  Widget _erroImagem() => Container(
        height: 200,
        color: Colors.grey.withOpacity(0.1),
        child: const Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.broken_image_rounded, size: 40, color: Colors.grey),
            SizedBox(height: 8),
            Text('Erro ao carregar página',
                style: TextStyle(color: Colors.grey, fontSize: 13)),
          ]),
        ),
      );

  Widget _buildBloqueioOffline(bool isDark, Color roxo) => Scaffold(
        backgroundColor:
            isDark ? const Color(0xFF0F0A1E) : const Color(0xFFF5F3FF),
        appBar: AppBar(
          backgroundColor: isDark ? const Color(0xFF1A1030) : roxo,
          foregroundColor: Colors.white,
          elevation: 0,
          title: Text(widget.capitulo,
              style: const TextStyle(fontWeight: FontWeight.w700)),
          centerTitle: true,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: roxo.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.wifi_off_rounded,
                    size: 56, color: roxo.withOpacity(0.5)),
              ),
              const SizedBox(height: 24),
              Text('Capítulo não baixado',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : Colors.black87)),
              const SizedBox(height: 10),
              Text(
                'Você está offline e este capítulo não foi baixado para leitura offline. Conecte-se à internet ou baixe o capítulo antes de sair.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: isDark ? Colors.white60 : Colors.black54),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: roxo,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  icon: const Icon(Icons.arrow_back_rounded),
                  label: const Text('Voltar',
                      style:
                          TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                ),
              ),
            ]),
          ),
        ),
      );
}
