import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../screens/grupo_chat_page.dart';
import '../services/auth_service.dart';
import '../models/usuario.dart';

class ComunidadePage extends StatefulWidget {
  const ComunidadePage({super.key});
  @override
  State<ComunidadePage> createState() => _ComunidadePageState();
}

class _ComunidadePageState extends State<ComunidadePage> {
  final _supabase = Supabase.instance.client;
  final _authService = AuthService();

  List<Map<String, dynamic>> _grupos = [];
  Usuario? _usuario;
  bool _carregando = true;

  // Ícones disponíveis para escolher ao criar grupo
  static const _icones = [
    'groups',
    'auto_stories',
    'local_fire_department',
    'flash_on',
    'shield',
    'sailing',
    'star',
    'favorite',
    'sports_martial_arts',
    'movie',
  ];

  @override
  void initState() {
    super.initState();
    _inicializar();
  }

  Future<void> _inicializar() async {
    _usuario = await _authService.getUsuarioInterno();
    if (!mounted) return;
    await _carregarGrupos();
  }

  Future<void> _carregarGrupos() async {
    setState(() => _carregando = true);
    try {
      final rows = await _supabase
          .from('grupos')
          .select()
          .order('criado_em', ascending: false);
      if (!mounted) return;
      setState(() {
        _grupos = List<Map<String, dynamic>>.from(rows);
        _carregando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _carregando = false);
    }
  }

  IconData _resolverIcone(String nome) {
    const mapa = {
      'groups': Icons.groups_rounded,
      'auto_stories': Icons.auto_stories_rounded,
      'local_fire_department': Icons.local_fire_department_rounded,
      'flash_on': Icons.flash_on_rounded,
      'shield': Icons.shield_rounded,
      'sailing': Icons.sailing_rounded,
      'star': Icons.star_rounded,
      'favorite': Icons.favorite_rounded,
      'sports_martial_arts': Icons.sports_martial_arts_rounded,
      'movie': Icons.movie_rounded,
    };
    return mapa[nome] ?? Icons.groups_rounded;
  }

  Future<void> _criarGrupo() async {
    if (_usuario == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Faça login para criar grupos.')),
      );
      return;
    }

    final nomeController = TextEditingController();
    final descController = TextEditingController();
    String iconeEscolhido = 'groups';

    final criou = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;
          final roxo =
              isDark ? const Color(0xFF9F67FA) : const Color(0xFF7C3AED);

          return AlertDialog(
            backgroundColor: isDark ? const Color(0xFF1A1030) : Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text('Criar grupo',
                style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : Colors.black87)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Nome
                  TextField(
                    controller: nomeController,
                    style: TextStyle(
                        color: isDark ? Colors.white : Colors.black87),
                    decoration: InputDecoration(
                      labelText: 'Nome do grupo *',
                      labelStyle: TextStyle(
                          color: isDark ? Colors.white54 : Colors.black45),
                      filled: true,
                      fillColor: isDark
                          ? const Color(0xFF231840)
                          : const Color(0xFFF5F3FF),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: roxo, width: 1.2)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Descrição
                  TextField(
                    controller: descController,
                    style: TextStyle(
                        color: isDark ? Colors.white : Colors.black87),
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: 'Descrição',
                      labelStyle: TextStyle(
                          color: isDark ? Colors.white54 : Colors.black45),
                      filled: true,
                      fillColor: isDark
                          ? const Color(0xFF231840)
                          : const Color(0xFFF5F3FF),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: roxo, width: 1.2)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Escolha de ícone
                  Text('Ícone do grupo',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white54 : Colors.black45)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _icones.map((ic) {
                      final selecionado = iconeEscolhido == ic;
                      return GestureDetector(
                        onTap: () => setDialogState(() => iconeEscolhido = ic),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: selecionado ? roxo : roxo.withOpacity(0.10),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color:
                                  selecionado ? roxo : roxo.withOpacity(0.20),
                            ),
                          ),
                          child: Icon(
                            _resolverIcone(ic),
                            color: selecionado ? Colors.white : roxo,
                            size: 22,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: roxo,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Criar',
                    style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ],
          );
        },
      ),
    );

    if (criou != true) return;

    final nome = nomeController.text.trim();
    if (nome.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('O nome do grupo é obrigatório.')),
      );
      return;
    }

    try {
      await _supabase.from('grupos').insert({
        'nome': nome,
        'descricao': descController.text.trim().isEmpty
            ? null
            : descController.text.trim(),
        'icone': iconeEscolhido,
        'criador_id': _usuario!.id,
      });
      await _carregarGrupos();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Grupo criado com sucesso!'),
            backgroundColor: Colors.green),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao criar grupo: $e')),
      );
    }
  }

  Future<void> _editarGrupo(Map<String, dynamic> grupo) async {
    final nomeController = TextEditingController(text: grupo['nome']);
    final descController =
        TextEditingController(text: grupo['descricao'] ?? '');
    String iconeEscolhido = grupo['icone'] ?? 'groups';

    final salvou = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;
          final roxo =
              isDark ? const Color(0xFF9F67FA) : const Color(0xFF7C3AED);

          return AlertDialog(
            backgroundColor: isDark ? const Color(0xFF1A1030) : Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text('Editar grupo',
                style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : Colors.black87)),
            content: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextField(
                  controller: nomeController,
                  style:
                      TextStyle(color: isDark ? Colors.white : Colors.black87),
                  decoration: InputDecoration(
                    labelText: 'Nome do grupo *',
                    labelStyle: TextStyle(
                        color: isDark ? Colors.white54 : Colors.black45),
                    filled: true,
                    fillColor: isDark
                        ? const Color(0xFF231840)
                        : const Color(0xFFF5F3FF),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: roxo, width: 1.2)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descController,
                  style:
                      TextStyle(color: isDark ? Colors.white : Colors.black87),
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'Descrição',
                    labelStyle: TextStyle(
                        color: isDark ? Colors.white54 : Colors.black45),
                    filled: true,
                    fillColor: isDark
                        ? const Color(0xFF231840)
                        : const Color(0xFFF5F3FF),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: roxo, width: 1.2)),
                  ),
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Ícone do grupo',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white54 : Colors.black45)),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _icones.map((ic) {
                    final selecionado = iconeEscolhido == ic;
                    return GestureDetector(
                      onTap: () => setDialogState(() => iconeEscolhido = ic),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: selecionado ? roxo : roxo.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color:
                                  selecionado ? roxo : roxo.withOpacity(0.20)),
                        ),
                        child: Icon(_resolverIcone(ic),
                            color: selecionado ? Colors.white : roxo, size: 22),
                      ),
                    );
                  }).toList(),
                ),
              ]),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: roxo,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Salvar',
                    style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ],
          );
        },
      ),
    );

    if (salvou != true) return;

    final nome = nomeController.text.trim();
    if (nome.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('O nome do grupo é obrigatório.')),
      );
      return;
    }

    try {
      await _supabase.from('grupos').update({
        'nome': nome,
        'descricao': descController.text.trim().isEmpty
            ? null
            : descController.text.trim(),
        'icone': iconeEscolhido,
      }).eq('id', grupo['id']);

      await _carregarGrupos();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Grupo atualizado!'), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao editar: $e')),
      );
    }
  }

  Future<void> _excluirGrupo(Map<String, dynamic> grupo) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Excluir grupo'),
        content: Text(
            'Excluir "${grupo['nome']}"? Todas as mensagens serão perdidas.'),
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
      // Remove mensagens do grupo primeiro
      await _supabase
          .from('mensagens_grupo')
          .delete()
          .eq('grupo', grupo['nome']);
      // Remove o grupo
      await _supabase.from('grupos').delete().eq('id', grupo['id']);

      await _carregarGrupos();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Grupo excluído.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao excluir: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final roxo = isDark ? const Color(0xFF9F67FA) : const Color(0xFF7C3AED);
    final fundo = isDark ? const Color(0xFF0F0A1E) : const Color(0xFFF5F3FF);
    final card = isDark ? const Color(0xFF1A1030) : Colors.white;

    return Container(
      color: fundo,
      child: SafeArea(
        child: Column(children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [const Color(0xFF1A1030), const Color(0xFF2D1B5E)]
                    : [const Color(0xFF7C3AED), const Color(0xFF9F67FA)],
              ),
            ),
            child: Row(children: [
              const Icon(Icons.groups_rounded, color: Colors.white, size: 26),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Comunidades',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w900)),
                      Text('Converse com outros fãs',
                          style:
                              TextStyle(color: Colors.white60, fontSize: 11)),
                    ]),
              ),
              // Botão criar grupo
              GestureDetector(
                onTap: _criarGrupo,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withOpacity(0.3)),
                  ),
                  child: const Icon(Icons.add_rounded,
                      color: Colors.white, size: 22),
                ),
              ),
            ]),
          ),

          // Lista
          Expanded(
            child: _carregando
                ? const Center(child: CircularProgressIndicator())
                : _grupos.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.groups_rounded,
                                  size: 64, color: roxo.withOpacity(0.3)),
                              const SizedBox(height: 16),
                              Text('Nenhum grupo ainda',
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: isDark
                                          ? Colors.white54
                                          : Colors.black45)),
                              const SizedBox(height: 8),
                              Text(
                                'Toque no + para criar o primeiro grupo!',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    fontSize: 13,
                                    color: isDark
                                        ? Colors.white38
                                        : Colors.black38),
                              ),
                            ],
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _carregarGrupos,
                        child: ListView.separated(
                          padding: const EdgeInsets.all(14),
                          itemCount: _grupos.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (_, i) {
                            final g = _grupos[i];

                            final eCriador = g['criador_id'] == _usuario?.id ||
                                _usuario?.role == 'admin';
                            final podeEditar =
                                g['criador_id'] == _usuario?.id ||
                                    _usuario?.role == 'admin';

                            return Container(
                              decoration: BoxDecoration(
                                color: card,
                                borderRadius: BorderRadius.circular(20),
                                border:
                                    Border.all(color: roxo.withOpacity(0.12)),
                                boxShadow: [
                                  BoxShadow(
                                      color: Colors.black
                                          .withOpacity(isDark ? 0.14 : 0.05),
                                      blurRadius: 10,
                                      offset: const Offset(0, 3))
                                ],
                              ),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(20),
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        GrupoChatPage(nomeGrupo: g['nome']),
                                  ),
                                ).then((_) => _carregarGrupos()),
                                child: Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Row(children: [
                                    // Ícone
                                    Container(
                                      width: 56,
                                      height: 56,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(16),
                                        gradient: LinearGradient(colors: [
                                          roxo,
                                          const Color(0xFF9F67FA)
                                        ]),
                                      ),
                                      child: Icon(
                                        _resolverIcone(g['icone'] ?? 'groups'),
                                        color: Colors.white,
                                        size: 26,
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    // Info
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(children: [
                                            Expanded(
                                              child: Text(
                                                g['nome'],
                                                style: TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w800,
                                                    color: isDark
                                                        ? Colors.white
                                                        : Colors.black87),
                                              ),
                                            ),
                                            // Badge "meu grupo"
                                            if (eCriador)
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 3),
                                                decoration: BoxDecoration(
                                                  color: roxo.withOpacity(0.12),
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          999),
                                                ),
                                                child: Text('Meu grupo',
                                                    style: TextStyle(
                                                        fontSize: 10,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        color: roxo)),
                                              ),
                                          ]),
                                          if (g['descricao'] != null &&
                                              g['descricao']
                                                  .toString()
                                                  .isNotEmpty) ...[
                                            const SizedBox(height: 4),
                                            Text(
                                              g['descricao'],
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                  fontSize: 12,
                                                  color: isDark
                                                      ? Colors.white60
                                                      : Colors.black54,
                                                  height: 1.3),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    // Seta ou botão excluir
                                    const SizedBox(width: 8),
                                    if (podeEditar)
                                      Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              icon: Icon(Icons.edit_rounded,
                                                  color: roxo, size: 20),
                                              onPressed: () => _editarGrupo(g),
                                            ),
                                            IconButton(
                                              icon: const Icon(
                                                  Icons.delete_rounded,
                                                  color: Colors.redAccent,
                                                  size: 20),
                                              onPressed: () => _excluirGrupo(g),
                                            ),
                                          ])
                                    else
                                      Icon(Icons.chevron_right_rounded,
                                          color: roxo.withOpacity(0.5)),
                                  ]),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ]),
      ),
    );
  }
}
