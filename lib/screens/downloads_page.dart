import 'dart:io';
import 'package:flutter/material.dart';
import '../repositories/downloads_repository.dart';
import '../repositories/capitulos_repository.dart';
import '../repositories/paginas_repository.dart';
import '../services/auth_service.dart';
import '../services/download_service.dart';
import '../models/download.dart';
import '../models/capitulo.dart';

class DownloadsPage extends StatefulWidget {
  const DownloadsPage({super.key});
  @override
  State<DownloadsPage> createState() => _DownloadsPageState();
}

class _DownloadsPageState extends State<DownloadsPage> {
  final _dRepo = DownloadsRepository.instance;
  final _cRepo = CapitulosRepository.instance;
  final _pRepo = PaginasRepository.instance;
  final _ds = DownloadService.instance;
  final _auth = AuthService();

  List<Download> _downloads = [];
  final Map<String, Capitulo> _caps = {};
  final Map<String, int> _tam = {};
  bool _loading = true;
  String? _uid;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() => _loading = true);
    final u = await _auth.getUsuarioInterno();
    if (!mounted) return;
    if (u == null) {
      setState(() => _loading = false);
      return;
    }
    _uid = u.id;
    final lista = (await _dRepo.listarPorUsuario(u.id))
        .where((d) => d.concluido)
        .toList();
    _caps.clear();
    _tam.clear();
    for (final d in lista) {
      final c = await _cRepo.buscarPorId(d.capituloId);
      if (c != null) _caps[d.capituloId] = c;
      if (d.caminhoLocal != null) {
        final t = await _tamanho(d.caminhoLocal!);
        if (t > 0) _tam[d.capituloId] = t;
      }
    }
    if (!mounted) return;
    setState(() {
      _downloads = lista;
      _loading = false;
    });
  }

  Future<int> _tamanho(String path) async {
    try {
      final dir = Directory(path);
      if (!await dir.exists()) return 0;
      int t = 0;
      await for (final e in dir.list(recursive: true)) {
        if (e is File) t += await e.length();
      }
      return t;
    } catch (_) {
      return 0;
    }
  }

  String _fmt(int bytes) {
    if (bytes <= 0) return '';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Future<void> _remover(Download d) async {
    if (_uid == null) return;
    final cap = _caps[d.capituloId];
    try {
      if (cap != null)
        await _ds.removerArquivosCapitulo(
            obraId: cap.obraId, capituloId: d.capituloId);
      final ps = await _pRepo.listarPorCapitulo(d.capituloId);
      for (final p in ps)
        if (p.imagemLocal != null && p.imagemLocal!.isNotEmpty) {
          final f = File(p.imagemLocal!);
          if (await f.exists()) await f.delete();
          await _pRepo.atualizarImagemLocal(paginaId: p.id, caminhoLocal: '');
        }
      await _cRepo.removerOffline(d.capituloId);
      await _dRepo.remover(_uid!, d.capituloId);
      await _carregar();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Download removido.'),
          behavior: SnackBarBehavior.floating));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erro: $e'), behavior: SnackBarBehavior.floating));
    }
  }

  void _confirmarRemocao(Download d) {
    final cap = _caps[d.capituloId];
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
        context: context,
        builder: (_) => AlertDialog(
              backgroundColor: isDark ? const Color(0xFF1A1030) : Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              title: const Text('Remover download',
                  style: TextStyle(fontWeight: FontWeight.w800)),
              content: Text(
                  'Remover "${cap?.titulo ?? 'este capítulo'}"?\nVocê precisará de internet para ler novamente.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancelar')),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _remover(d);
                  },
                  child: const Text('Remover',
                      style: TextStyle(
                          color: Colors.redAccent,
                          fontWeight: FontWeight.w700)),
                ),
              ],
            ));
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
              const Icon(Icons.download_rounded, color: Colors.white, size: 26),
              const SizedBox(width: 10),
              const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Downloads',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w900)),
                    Text('Capítulos disponíveis offline',
                        style: TextStyle(color: Colors.white60, fontSize: 11)),
                  ]),
            ]),
          ),
          // Conteúdo
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _downloads.isEmpty
                    ? _vazio(roxo, isDark)
                    : RefreshIndicator(
                        onRefresh: _carregar,
                        child: ListView.separated(
                          padding: const EdgeInsets.all(14),
                          itemCount: _downloads.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (_, i) {
                            final d = _downloads[i];
                            final cap = _caps[d.capituloId];
                            final tam = _tam[d.capituloId] ?? 0;
                            return Container(
                              decoration: BoxDecoration(
                                color: card,
                                borderRadius: BorderRadius.circular(18),
                                border:
                                    Border.all(color: roxo.withOpacity(0.12)),
                                boxShadow: [
                                  BoxShadow(
                                      color: Colors.black
                                          .withOpacity(isDark ? 0.14 : 0.04),
                                      blurRadius: 8,
                                      offset: const Offset(0, 3))
                                ],
                              ),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(18),
                                onTap: () {
                                  if (cap == null) return;
                                  Navigator.pushNamed(context, '/leitura',
                                      arguments: {
                                        'obraId': cap.obraId,
                                        'capituloId': cap.id,
                                        'capitulo': cap.titulo,
                                        'titulo': cap.titulo,
                                      }).then((_) => _carregar());
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 12),
                                  child: Row(children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                          color: roxo.withOpacity(0.12),
                                          borderRadius:
                                              BorderRadius.circular(12)),
                                      child: Icon(Icons.download_done_rounded,
                                          color: roxo, size: 22),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                        child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                          Text(cap?.titulo ?? 'Capítulo',
                                              style: TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 15,
                                                  color: isDark
                                                      ? Colors.white
                                                      : Colors.black87)),
                                          const SizedBox(height: 3),
                                          Row(children: [
                                            Icon(Icons.offline_pin_rounded,
                                                size: 12,
                                                color: Colors.green.shade400),
                                            const SizedBox(width: 4),
                                            Text('Disponível offline',
                                                style: TextStyle(
                                                    fontSize: 12,
                                                    color:
                                                        Colors.green.shade400)),
                                          ]),
                                          if (tam > 0)
                                            Text(_fmt(tam),
                                                style: TextStyle(
                                                    fontSize: 11,
                                                    color: isDark
                                                        ? Colors.white38
                                                        : Colors.black38)),
                                        ])),
                                    IconButton(
                                      icon: const Icon(Icons.delete_rounded,
                                          color: Colors.redAccent),
                                      onPressed: () => _confirmarRemocao(d),
                                    ),
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

  Widget _vazio(Color roxo, bool isDark) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                    color: roxo.withOpacity(0.10), shape: BoxShape.circle),
                child: Icon(Icons.download_for_offline_outlined,
                    size: 52, color: roxo.withOpacity(0.5))),
            const SizedBox(height: 16),
            Text('Nenhum capítulo baixado',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white70 : Colors.black54)),
            const SizedBox(height: 8),
            Text('Baixe capítulos na página de detalhes para ler offline.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white38 : Colors.black38)),
          ]),
        ),
      );
}
