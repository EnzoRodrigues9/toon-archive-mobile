import 'package:flutter/material.dart';
import '../repositories/favoritos_repository.dart';
import '../repositories/generos_repository.dart';
import '../services/auth_service.dart';
import '../models/obra.dart';
import '../models/genero.dart';

class ObraCard extends StatefulWidget {
  final Obra obra;
  final VoidCallback? onFavoritoAlterado;

  const ObraCard({super.key, required this.obra, this.onFavoritoAlterado});

  @override
  State<ObraCard> createState() => _ObraCardState();
}

class _ObraCardState extends State<ObraCard> {
  bool _isFavorito = false;
  bool _carregando = true;
  String? _usuarioId;
  List<Genero> _generos = [];

  final _favoritosRepo = FavoritosRepository.instance;
  final _generosRepo   = GenerosRepository.instance;
  final _authService   = AuthService();

  @override
  void initState() {
    super.initState();
    _inicializar();
  }

  @override
  void didUpdateWidget(covariant ObraCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.obra.id != widget.obra.id) _carregarFavorito();
  }

  Future<void> _inicializar() async {
    final usuario = await _authService.getUsuarioInterno();
    if (!mounted) return;
    _usuarioId = usuario?.id;
    await Future.wait([_carregarFavorito(), _carregarGeneros()]);
  }

  Future<void> _carregarFavorito() async {
    if (_usuarioId == null) {
      if (mounted) setState(() => _carregando = false);
      return;
    }
    final resultado = await _favoritosRepo.isFavorito(_usuarioId!, widget.obra.id);
    if (!mounted) return;
    setState(() { _isFavorito = resultado; _carregando = false; });
  }

  Future<void> _carregarGeneros() async {
    final generos = await _generosRepo.listarPorObra(widget.obra.id);
    if (!mounted) return;
    setState(() => _generos = generos);
  }

  Future<void> _toggleFavorito() async {
    if (_usuarioId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Faça login para favoritar obras.')),
      );
      return;
    }
    setState(() => _isFavorito = !_isFavorito);
    try {
      await _favoritosRepo.toggle(_usuarioId!, widget.obra.id);
      widget.onFavoritoAlterado?.call();
    } catch (e) {
      if (mounted) setState(() => _isFavorito = !_isFavorito);
    }
  }

  Widget _buildCapa(Color roxo) {
    final src = (widget.obra.capaUrl?.isNotEmpty ?? false) ? widget.obra.capaUrl : null;
    if (src == null) {
      return Container(
        color: roxo.withOpacity(0.15),
        child: Center(child: Icon(Icons.menu_book_rounded, color: roxo, size: 36)),
      );
    }
    return Image.network(src, fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          color: roxo.withOpacity(0.15),
          child: Center(child: Icon(Icons.menu_book_rounded, color: roxo, size: 36)),
        ));
  }

  String _statusLabel() {
    switch (widget.obra.status) {
      case 'em_andamento': return 'Em andamento';
      case 'completa':     return 'Completa';
      case 'hiato':        return 'Hiato';
      case 'cancelada':    return 'Cancelada';
      default:             return widget.obra.status;
    }
  }

  Color _statusColor() {
    switch (widget.obra.status) {
      case 'em_andamento': return Colors.green;
      case 'completa':     return Colors.blue;
      case 'hiato':        return Colors.orange;
      case 'cancelada':    return Colors.red;
      default:             return Colors.grey;
    }
  }

  // Mostra só narrativo + tipo no card (demografico fica no detalhe)
  List<Genero> get _generosCard =>
      _generos.where((g) => g.categoria != 'demografico').take(3).toList();

  @override
  Widget build(BuildContext context) {
    final isDark    = Theme.of(context).brightness == Brightness.dark;
    final roxo      = isDark ? const Color(0xFF9F67FA) : const Color(0xFF7C3AED);
    final cardColor = isDark ? const Color(0xFF1A1030) : Colors.white;

    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/detalhe',
        arguments: {'obraId': widget.obra.id, 'titulo': widget.obra.titulo},
      ).then((_) { _carregarFavorito(); widget.onFavoritoAlterado?.call(); }),
      child: Container(
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: roxo.withOpacity(0.12)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.06),
              blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Row(children: [
          // Capa
          SizedBox(
            width: 90, height: 130,
            child: ClipRRect(
              borderRadius: const BorderRadius.horizontal(left: Radius.circular(16)),
              child: _buildCapa(roxo),
            ),
          ),
          // Info
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Título
                  Text(widget.obra.titulo,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15,
                        color: isDark ? Colors.white : Colors.black87)),
                  if (widget.obra.autor?.isNotEmpty ?? false) ...[
                    const SizedBox(height: 2),
                    Text(widget.obra.autor!, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11,
                            color: isDark ? Colors.white54 : Colors.black45)),
                  ],
                  const SizedBox(height: 5),
                  // Descrição
                  Text(widget.obra.descricao ?? '', maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, height: 1.3,
                          color: isDark ? Colors.white60 : Colors.black54)),
                  const SizedBox(height: 7),
                  // Chips de gênero (narrativo + tipo)
                  if (_generosCard.isNotEmpty)
                    Wrap(spacing: 4, runSpacing: 4,
                      children: _generosCard.map((g) => _chip(
                        g.nome,
                        cor: g.categoria == 'tipo' ? Colors.blueGrey : roxo,
                      )).toList(),
                    ),
                  const SizedBox(height: 7),
                  // Rodapé: status + favorito
                  Row(children: [
                    _chip(_statusLabel(), cor: _statusColor()),
                    const Spacer(),
                    _carregando
                        ? const SizedBox(width: 20, height: 20,
                            child: CircularProgressIndicator(strokeWidth: 1.5))
                        : GestureDetector(
                            onTap: _toggleFavorito,
                            child: Icon(
                              _isFavorito ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                              color: _isFavorito ? Colors.redAccent
                                  : (isDark ? Colors.white38 : Colors.black26),
                              size: 22,
                            ),
                          ),
                  ]),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: Icon(Icons.chevron_right_rounded, color: roxo.withOpacity(0.5), size: 22),
          ),
        ]),
      ),
    );
  }

  Widget _chip(String texto, {required Color cor}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: cor.withOpacity(0.12),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(texto,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: cor)),
  );
}