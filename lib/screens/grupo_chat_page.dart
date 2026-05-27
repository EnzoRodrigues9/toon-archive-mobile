import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';
import '../models/usuario.dart';

class GrupoChatPage extends StatefulWidget {
  final String nomeGrupo;
  const GrupoChatPage({super.key, required this.nomeGrupo});
  @override
  State<GrupoChatPage> createState() => _GrupoChatPageState();
}

class _GrupoChatPageState extends State<GrupoChatPage> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _supabase = Supabase.instance.client;
  final _authService = AuthService();

  List<Map<String, dynamic>> _mensagens = [];
  Usuario? _usuario;
  bool _carregando = true;
  bool _enviando = false;

  @override
  void initState() {
    super.initState();
    _inicializar();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
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
            // evita duplicar mensagem própria que já foi adicionada otimisticamente
            final jaExiste =
                _mensagens.any((m) => m['id'] == nova['id']);
            if (!jaExiste) {
              setState(() => _mensagens.add(nova));
              _rolarParaBaixo();
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
    if (_usuario == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Faça login para enviar mensagens.')),
      );
      return;
    }

    setState(() => _enviando = true);
    _controller.clear();

    try {
      await _supabase.from('mensagens_grupo').insert({
        'grupo':        widget.nomeGrupo,
        'usuario_id':   _usuario!.id,
        'nome_usuario': _usuario!.nome,
        'conteudo':     texto,
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao enviar: $e')),
      );
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  Future<void> _editar(Map<String, dynamic> msg) async {
    _controller.text = msg['conteudo'];
    final salvar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Editar mensagem'),
        content: TextField(
          controller: _controller,
          autofocus: true,
          maxLines: null,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Salvar'),
          ),
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
          .update({'conteudo': _controller.text.trim(), 'editado': true})
          .eq('id', msg['id']);

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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao editar: $e')),
      );
    }
    _controller.clear();
  }

  Future<void> _excluir(Map<String, dynamic> msg) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Excluir mensagem'),
        content: const Text('Tem certeza que deseja excluir esta mensagem?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Excluir',
                style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    try {
      await _supabase
          .from('mensagens_grupo')
          .delete()
          .eq('id', msg['id']);

      if (!mounted) return;
      setState(() => _mensagens.removeWhere((m) => m['id'] == msg['id']));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao excluir: $e')),
      );
    }
  }

  bool _eMinha(Map<String, dynamic> msg) =>
      msg['usuario_id'] == _usuario?.id;

  String _formatarData(String iso) {
    final dt = DateTime.parse(iso).toLocal();
    return DateFormat('HH:mm').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final roxo = isDark ? const Color(0xFF9F67FA) : const Color(0xFF7C3AED);
    final fundo = isDark ? const Color(0xFF0F0A1E) : const Color(0xFFF5F3FF);

    return Scaffold(
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
                      child: Text(
                        'Nenhuma mensagem ainda.\nSeja o primeiro a comentar!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: isDark ? Colors.white38 : Colors.black38),
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(14),
                      itemCount: _mensagens.length,
                      itemBuilder: (_, i) {
                        final msg = _mensagens[i];
                        final minha = _eMinha(msg);
                        return Align(
                          alignment: minha
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            constraints:
                                const BoxConstraints(maxWidth: 300),
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: minha
                                  ? (isDark
                                      ? const Color(0xFF5B21B6)
                                      : const Color(0xFF7C3AED))
                                  : (isDark
                                      ? const Color(0xFF1A1030)
                                      : Colors.white),
                              borderRadius: BorderRadius.only(
                                topLeft: const Radius.circular(18),
                                topRight: const Radius.circular(18),
                                bottomLeft:
                                    Radius.circular(minha ? 18 : 4),
                                bottomRight:
                                    Radius.circular(minha ? 4 : 18),
                              ),
                              border: Border.all(
                                  color: roxo
                                      .withOpacity(minha ? 0 : 0.14)),
                              boxShadow: [
                                BoxShadow(
                                    color:
                                        Colors.black.withOpacity(0.06),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2))
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                // Nome do usuário (só em mensagens alheias)
                                if (!minha)
                                  Padding(
                                    padding: const EdgeInsets.only(
                                        bottom: 4),
                                    child: Text(
                                      msg['nome_usuario'] ?? 'Usuário',
                                      style: TextStyle(
                                          color: roxo,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 12),
                                    ),
                                  ),
                                // Conteúdo + botões de editar/excluir
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        msg['conteudo'],
                                        style: TextStyle(
                                            color: minha
                                                ? Colors.white
                                                : (isDark
                                                    ? Colors.white
                                                    : Colors.black87)),
                                      ),
                                    ),
                                    if (minha) ...[
                                      const SizedBox(width: 4),
                                      GestureDetector(
                                        onTap: () => _editar(msg),
                                        child: Icon(Icons.edit_rounded,
                                            size: 16,
                                            color: Colors.white
                                                .withOpacity(0.7)),
                                      ),
                                      const SizedBox(width: 2),
                                      GestureDetector(
                                        onTap: () => _excluir(msg),
                                        child: Icon(
                                            Icons.delete_rounded,
                                            size: 16,
                                            color: Colors.white
                                                .withOpacity(0.7)),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 4),
                                // Hora + editado
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment:
                                      MainAxisAlignment.end,
                                  children: [
                                    if (msg['editado'] == true)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                            right: 4),
                                        child: Text(
                                          'editado',
                                          style: TextStyle(
                                              fontSize: 9,
                                              color: minha
                                                  ? Colors.white54
                                                  : (isDark
                                                      ? Colors.white38
                                                      : Colors
                                                          .black38)),
                                        ),
                                      ),
                                    Text(
                                      _formatarData(
                                          msg['criado_em'] ?? ''),
                                      style: TextStyle(
                                          fontSize: 10,
                                          color: minha
                                              ? Colors.white60
                                              : (isDark
                                                  ? Colors.white38
                                                  : Colors.black38)),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
        ),
        // Input
        SafeArea(
          top: false,
          child: Container(
            padding: EdgeInsets.fromLTRB(
                12, 8, 12, MediaQuery.of(context).viewInsets.bottom + 8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1A1030) : Colors.white,
              border:
                  Border(top: BorderSide(color: roxo.withOpacity(0.12))),
            ),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  style: TextStyle(
                      color: isDark ? Colors.white : Colors.black87),
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _enviar(),
                  decoration: InputDecoration(
                    hintText: 'Digite sua mensagem...',
                    hintStyle: TextStyle(
                        color: isDark ? Colors.white38 : Colors.black38,
                        fontSize: 14),
                    filled: true,
                    fillColor: isDark
                        ? const Color(0xFF231840)
                        : const Color(0xFFF5F3FF),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide:
                            BorderSide(color: roxo, width: 1.2)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _enviando ? null : _enviar,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                        colors: [roxo, const Color(0xFF9F67FA)]),
                    shape: BoxShape.circle,
                  ),
                  child: _enviando
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2),
                        )
                      : const Icon(Icons.send_rounded,
                          color: Colors.white, size: 20),
                ),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}