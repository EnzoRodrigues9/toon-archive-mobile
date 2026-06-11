import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:toonarchive/app/core/services/auth_service.dart';
import 'package:toonarchive/app/modules/usuarios/usuario.dart';
import 'package:toonarchive/app/core/helpers/app.config.dart';

class GrupoChatPage extends StatefulWidget {
  final String nomeGrupo;
  const GrupoChatPage({super.key, required this.nomeGrupo});
  @override
  State<GrupoChatPage> createState() => _GrupoChatPageState();
}

class _GrupoChatPageState extends State<GrupoChatPage>
    with WidgetsBindingObserver {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _supabase = Supabase.instance.client;
  final _authService = AuthService();
  final _picker = ImagePicker();

  List<Map<String, dynamic>> _mensagens = [];
  Usuario? _usuario;
  bool _carregando = true;
  bool _enviando = false;
  bool _mostrarEmoji = false;
  bool _mostrarMidia = false;

  List<Map<String, dynamic>> _gifs = [];
  bool _carregandoGifs = false;
  final _gifController = TextEditingController();
  final _gifFocusNode = FocusNode();
  bool _gifFieldFocado = false;

  final List<String> _stickers = [
    'https://media.giphy.com/media/xT9IgG50Lg7russbD6/giphy.gif',
    'https://media.giphy.com/media/3oEjI6SIIHBdRxXI40/giphy.gif',
    'https://media.giphy.com/media/l0MYt5jPR6QX5pnqM/giphy.gif',
    'https://media.giphy.com/media/26ufdipQqU2lhNA4g/giphy.gif',
    'https://media.giphy.com/media/3oz8xIsloV7zOmt81G/giphy.gif',
    'https://media.giphy.com/media/xT5LMHxhOfscxPfIfm/giphy.gif',
  ];

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
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    _scrollController.dispose();
    _gifController.dispose();
    _gifFocusNode.dispose();
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    final bottomInset = WidgetsBinding
        .instance.platformDispatcher.views.first.viewInsets.bottom;
    if (bottomInset > 100 &&
        (_mostrarEmoji || _mostrarMidia) &&
        !_gifFieldFocado) {
      setState(() {
        _mostrarEmoji = false;
        _mostrarMidia = false;
      });
    }
  }

  Future<void> _inicializar() async {
    _usuario = await _authService.getUsuarioInterno();
    if (!mounted) return;
    await _carregarMensagens();
    _inscreverRealtime();
  }

  Future<void> _carregarMensagens() async {
    try {
      final rows = await _supabase
          .from('mensagens_grupo')
          .select()
          .eq('grupo', widget.nomeGrupo)
          .order('criado_em', ascending: true);
      if (!mounted) return;
      setState(() {
        _mensagens = List<Map<String, dynamic>>.from(rows);
        _carregando = false;
      });
      _rolarParaBaixo();
    } catch (e) {
      if (!mounted) return;
      setState(() => _carregando = false);
    }
  }

  void _inscreverRealtime() {
    _supabase
        .channel('grupo_${widget.nomeGrupo}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'mensagens_grupo',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'grupo',
            value: widget.nomeGrupo,
          ),
          callback: (payload) {
            if (!mounted) return;
            final nova = payload.newRecord;
            final jaExiste = _mensagens.any((m) =>
                m['id'] == nova['id'] ||
                (m['usuario_id'] == nova['usuario_id'] &&
                    m['conteudo'] == nova['conteudo'] &&
                    m['id'].toString().startsWith('temp_')));
            if (!jaExiste) {
              setState(() => _mensagens.add(nova));
              _rolarParaBaixo();
            } else {
              setState(() {
                final i = _mensagens.indexWhere((m) =>
                    m['id'].toString().startsWith('temp_') &&
                    m['conteudo'] == nova['conteudo'] &&
                    m['usuario_id'] == nova['usuario_id']);
                if (i != -1) _mensagens[i] = nova;
              });
            }
          },
        )
        .subscribe();
  }

  void _rolarParaBaixo() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _enviar() async {
    final texto = _controller.text.trim();
    if (texto.isEmpty || _enviando) return;
    if (_usuario == null) return;

    setState(() {
      _enviando = true;
      _mostrarEmoji = false;
    });
    _controller.clear();

    final temp = {
      'id': 'temp_${DateTime.now().millisecondsSinceEpoch}',
      'grupo': widget.nomeGrupo,
      'usuario_id': _usuario!.id,
      'nome_usuario': _usuario!.nome,
      'conteudo': texto,
      'tipo': 'texto',
      'media_url': null,
      'criado_em': DateTime.now().toIso8601String(),
      'editado': false,
    };
    setState(() => _mensagens.add(temp));
    _rolarParaBaixo();

    try {
      final row = await _supabase
          .from('mensagens_grupo')
          .insert({
            'grupo': widget.nomeGrupo,
            'usuario_id': _usuario!.id,
            'nome_usuario': _usuario!.nome,
            'conteudo': texto,
            'tipo': 'texto',
          })
          .select()
          .single();
      if (!mounted) return;
      setState(() {
        final i = _mensagens.indexWhere((m) => m['id'] == temp['id']);
        if (i != -1) _mensagens[i] = row;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _mensagens.removeWhere((m) => m['id'] == temp['id']));
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Erro ao enviar: $e')));
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  Future<void> _enviarMidia({
    required String tipo,
    required String conteudo,
    required String? mediaUrl,
  }) async {
    if (_usuario == null) return;
    setState(() => _enviando = true);
    try {
      await _supabase.from('mensagens_grupo').insert({
        'grupo': widget.nomeGrupo,
        'usuario_id': _usuario!.id,
        'nome_usuario': _usuario!.nome,
        'conteudo': conteudo,
        'tipo': tipo,
        'media_url': mediaUrl,
      });
      _rolarParaBaixo();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Erro ao enviar mídia: $e')));
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  Future<void> _enviarFoto({bool camera = false}) async {
    setState(() => _mostrarMidia = false);
    final xfile = await _picker.pickImage(
      source: camera ? ImageSource.camera : ImageSource.gallery,
      imageQuality: 70,
      maxWidth: 1200,
    );
    if (xfile == null) return;

    setState(() => _enviando = true);
    try {
      final bytes = await xfile.readAsBytes();
      final ext = xfile.path.split('.').last;
      final path =
          'chat/${widget.nomeGrupo}/${_usuario!.id}_${DateTime.now().millisecondsSinceEpoch}.$ext';

      await _supabase.storage.from('chat-media').uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(contentType: 'image/$ext'),
          );

      final url = _supabase.storage.from('chat-media').getPublicUrl(path);
      await _enviarMidia(tipo: 'imagem', conteudo: '📷 Foto', mediaUrl: url);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Erro no upload: $e')));
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  Future<void> _buscarGifs(String query) async {
    setState(() => _carregandoGifs = true);
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
      final data = (json['data'] as List);
      setState(() {
        _gifs = data
            .map((g) => {
                  'preview': g['images']['fixed_height_small']['url'] as String,
                  'url': g['images']['original']['url'] as String,
                })
            .toList();
        _carregandoGifs = false;
      });
    } catch (_) {
      setState(() => _carregandoGifs = false);
    }
  }

  Future<void> _editar(Map<String, dynamic> msg) async {
    _controller.text = msg['conteudo'];
    final salvar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Editar mensagem'),
        content:
            TextField(controller: _controller, autofocus: true, maxLines: null),
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
    if (salvar != true || _controller.text.trim().isEmpty) {
      _controller.clear();
      return;
    }
    try {
      await _supabase
          .from('mensagens_grupo')
          .update({'conteudo': _controller.text.trim(), 'editado': true}).eq(
              'id', msg['id']);
      if (!mounted) return;
      setState(() {
        final i = _mensagens.indexWhere((m) => m['id'] == msg['id']);
        if (i != -1) {
          _mensagens[i]['conteudo'] = _controller.text.trim();
          _mensagens[i]['editado'] = true;
        }
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Erro: $e')));
    }
    _controller.clear();
  }

  Future<void> _excluir(Map<String, dynamic> msg) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Excluir mensagem'),
        content: const Text('Tem certeza?'),
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
    if (ok != true) return;
    try {
      await _supabase.from('mensagens_grupo').delete().eq('id', msg['id']);
      if (!mounted) return;
      setState(() => _mensagens.removeWhere((m) => m['id'] == msg['id']));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Erro: $e')));
    }
  }

  bool _eMinha(Map<String, dynamic> msg) =>
      msg['usuario_id'] == _usuario?.id || _usuario?.role == 'admin';

  String _formatarData(String iso) {
    final dt = DateTime.parse(iso).toLocal();
    final agora = DateTime.now();
    final hoje = DateTime(agora.year, agora.month, agora.day);
    final ontem = hoje.subtract(const Duration(days: 1));
    final dia = DateTime(dt.year, dt.month, dt.day);
    final hora = DateFormat('HH:mm').format(dt);
    if (dia == hoje) return 'Hoje, $hora';
    if (dia == ontem) return 'Ontem, $hora';
    return '${DateFormat('dd/MM/yyyy').format(dt)}, $hora';
  }

  // ══════════════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final roxo = isDark ? const Color(0xFF9F67FA) : const Color(0xFF7C3AED);
    final fundo = isDark ? const Color(0xFF0F0A1E) : const Color(0xFFF5F3FF);

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: fundo,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1A1030) : roxo,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text(widget.nomeGrupo,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
      ),
      body: Column(children: [
        Expanded(
          child: _carregando
              ? const Center(child: CircularProgressIndicator())
              : _mensagens.isEmpty
                  ? Center(
                      child: Text('Nenhuma mensagem.',
                          style: TextStyle(
                              color: isDark ? Colors.white38 : Colors.black38)))
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(14),
                      itemCount: _mensagens.length,
                      itemBuilder: (_, i) =>
                          _buildCard(_mensagens[i], isDark, roxo),
                    ),
        ),
        if (_mostrarEmoji)
          SizedBox(
            height: 280,
            child: EmojiPicker(
              onEmojiSelected: (_, emoji) => _controller.text += emoji.emoji,
              config: Config(
                height: 280,
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
        _buildInput(isDark, roxo),
      ]),
    );
  }

  // ── Card de mensagem ─────────────────

  Widget _buildCard(Map<String, dynamic> msg, bool isDark, Color roxo) {
    final minha = _eMinha(msg);
    final tipo = msg['tipo'] ?? 'texto';
    final eMidia = tipo == 'imagem' || tipo == 'gif' || tipo == 'sticker';

    final bubble = Container(
      constraints:
          BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: minha
            ? roxo
            : (isDark ? const Color(0xFF20172C) : const Color(0xFFF0EBFF)),
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(16),
          topRight: const Radius.circular(16),
          bottomLeft: Radius.circular(minha ? 16 : 4),
          bottomRight: Radius.circular(minha ? 4 : 16),
        ),
        border: minha ? null : Border.all(color: roxo.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!minha)
            Text(
              msg['nome_usuario'] ?? 'Usuário',
              style: TextStyle(
                  color: roxo, fontWeight: FontWeight.w800, fontSize: 12),
            ),
          if (!minha) const SizedBox(height: 3),
          if (eMidia && msg['media_url'] != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(
                msg['media_url'],
                width: tipo == 'sticker' ? 100 : 220,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Icon(
                    Icons.broken_image_rounded,
                    size: 40,
                    color: Colors.grey),
              ),
            )
          else
            Text(
              msg['conteudo'] ?? '',
              style: TextStyle(
                fontSize: 14,
                height: 1.4,
                color: minha
                    ? Colors.white
                    : (isDark ? Colors.white : Colors.black87),
              ),
            ),
          const SizedBox(height: 3),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _formatarData(msg['criado_em'] ?? ''),
                style: TextStyle(
                  fontSize: 10,
                  color: minha
                      ? Colors.white60
                      : (isDark ? Colors.white38 : Colors.black38),
                ),
              ),
              if (msg['editado'] == true)
                Text(
                  ' · editado',
                  style: TextStyle(
                      fontSize: 10,
                      color: minha ? Colors.white60 : Colors.black38),
                ),
            ],
          ),
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 8),
      child: Row(
        mainAxisAlignment:
            minha ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (minha) ...[
            Row(children: [
              GestureDetector(
                  onTap: () => _excluir(msg),
                  child: const Icon(Icons.delete_rounded,
                      color: Colors.redAccent, size: 16)),
              if (!eMidia) ...[
                const SizedBox(width: 4),
                GestureDetector(
                    onTap: () => _editar(msg),
                    child: Icon(Icons.edit_rounded, color: roxo, size: 16)),
              ],
              const SizedBox(width: 6),
            ]),
            bubble,
          ] else
            bubble,
        ],
      ),
    );
  }

  // ── Painel mídia ───────────────────────────────────────────

  Widget _buildPainelMidia(bool isDark, Color roxo) {
    return Container(
      height: 340,
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
              // GIFs
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
                                  setState(() => _mostrarMidia = false);
                                  await _enviarMidia(
                                    tipo: 'gif',
                                    conteudo: '🎞️ GIF',
                                    mediaUrl: _gifs[i]['url'],
                                  );
                                },
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(_gifs[i]['preview'],
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Container(
                                          color: roxo.withOpacity(0.1))),
                                ),
                              ),
                            ),
                ),
              ]),

              // Stickers
              GridView.builder(
                padding: const EdgeInsets.all(8),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3, crossAxisSpacing: 6, mainAxisSpacing: 6),
                itemCount: _stickers.length,
                itemBuilder: (_, i) => GestureDetector(
                  onTap: () async {
                    setState(() => _mostrarMidia = false);
                    await _enviarMidia(
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

              // Foto
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

  // ── Input ──────────────────────────────────────────────────

  Widget _buildInput(bool isDark, Color roxo) {
    return SafeArea(
      top: false,
      child: Container(
        padding: EdgeInsets.fromLTRB(
            8, 8, 8, MediaQuery.of(context).viewInsets.bottom + 8),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1030) : Colors.white,
          border: Border(top: BorderSide(color: roxo.withOpacity(0.12))),
        ),
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
              setState(() {
                _mostrarEmoji = !_mostrarEmoji;
                if (_mostrarEmoji) _mostrarMidia = false;
              });
            },
          ),
          Expanded(
            child: TextField(
              controller: _controller,
              style: TextStyle(color: isDark ? Colors.white : Colors.black87),
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _enviar(),
              onTap: () =>
                  setState(() => _mostrarEmoji = _mostrarMidia = false),
              decoration: InputDecoration(
                hintText: 'Digite sua mensagem...',
                hintStyle: TextStyle(
                    color: isDark ? Colors.white38 : Colors.black38,
                    fontSize: 14),
                filled: true,
                fillColor:
                    isDark ? const Color(0xFF231840) : const Color(0xFFF5F3FF),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide(color: roxo, width: 1.2)),
              ),
            ),
          ),
          IconButton(
            icon: Icon(
              _mostrarMidia ? Icons.close_rounded : Icons.add_circle_rounded,
              color: roxo,
            ),
            onPressed: () async {
              FocusScope.of(context).unfocus();
              await Future.delayed(const Duration(milliseconds: 150));
              if (!mounted) return;
              setState(() {
                _mostrarMidia = !_mostrarMidia;
                if (_mostrarMidia) _mostrarEmoji = false;
              });
            },
          ),
          GestureDetector(
            onTap: _enviando ? null : _enviar,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient:
                    LinearGradient(colors: [roxo, const Color(0xFF9F67FA)]),
                shape: BoxShape.circle,
              ),
              child: _enviando
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.send_rounded,
                      color: Colors.white, size: 20),
            ),
          ),
        ]),
      ),
    );
  }
}
