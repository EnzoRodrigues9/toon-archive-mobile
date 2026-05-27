import 'package:flutter/material.dart';
import '../repositories/favoritos_repository.dart';
import '../services/auth_service.dart';
import '../models/obra.dart';

class ObraCard extends StatefulWidget {
  final Obra obra;
  final VoidCallback? onFavoritoAlterado;

  const ObraCard({
    super.key,
    required this.obra,
    this.onFavoritoAlterado,
  });

  @override
  State<ObraCard> createState() => _ObraCardState();
}

class _ObraCardState extends State<ObraCard> {
  bool _isFavorito = false;
  bool _carregando = true;
  String? _usuarioId;

  final _favoritosRepo = FavoritosRepository.instance;
  final _authService = AuthService();

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
    await _carregarFavorito();
  }

  Future<void> _carregarFavorito() async {
    if (_usuarioId == null) {
      if (mounted) setState(() => _carregando = false);
      return;
    }
    final resultado =
        await _favoritosRepo.isFavorito(_usuarioId!, widget.obra.id);
    if (!mounted) return;
    setState(() {
      _isFavorito = resultado;
      _carregando = false;
    });
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
      debugPrint('Erro ao alternar favorito: $e');
    }
  }

  // Agora só usa URL remota — sem fallback local
  String? _resolverImagem() {
    if (widget.obra.capaUrl != null && widget.obra.capaUrl!.isNotEmpty) {
      return widget.obra.capaUrl!;
    }
    return null;
  }

  Widget _buildCapa(Color roxo) {
    final src = _resolverImagem();

    if (src == null) {
      return Container(
        color: roxo.withOpacity(0.15),
        child: Center(
          child: Icon(Icons.menu_book_rounded, color: roxo, size: 36),
        ),
      );
    }

    return Image.network(
      src,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(
        color: roxo.withOpacity(0.15),
        child: Center(
          child: Icon(Icons.menu_book_rounded, color: roxo, size: 36),
        ),
      ),
    );
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final roxo = isDark ? const Color(0xFF9F67FA) : const Color(0xFF7C3AED);
    final cardColor = isDark ? const Color(0xFF1A1030) : Colors.white;

    return GestureDetector(
      onTap: () {
        Navigator.pushNamed(
          context,
          '/detalhe',
          arguments: {
            'obraId': widget.obra.id,
            'titulo': widget.obra.titulo,
          },
        ).then((_) {
          _carregarFavorito();
          widget.onFavoritoAlterado?.call();
        });
      },
      child: Container(
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: roxo.withOpacity(0.12)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.2 : 0.06),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // ── Capa ──────────────────────────────────────
            SizedBox(
              width: 90,
              height: 120,
              child: ClipRRect(
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(16),
                ),
                child: _buildCapa(roxo),
              ),
            ),

            // ── Informações ───────────────────────────────
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Título
                    Text(
                      widget.obra.titulo,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),

                    // Autor
                    if (widget.obra.autor != null &&
                        widget.obra.autor!.isNotEmpty)
                      Text(
                        widget.obra.autor!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white54 : Colors.black45,
                        ),
                      ),
                    const SizedBox(height: 6),

                    // Descrição
                    Text(
                      widget.obra.descricao ?? '',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Rodapé: gênero + status + favorito
                    Row(
                      children: [
                        if (widget.obra.genero != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: roxo.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              widget.obra.genero!,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: roxo,
                              ),
                            ),
                          ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: _statusColor().withOpacity(0.12),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            _statusLabel(),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: _statusColor(),
                            ),
                          ),
                        ),
                        const Spacer(),
                        _carregando
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 1.5),
                              )
                            : GestureDetector(
                                onTap: _toggleFavorito,
                                child: Icon(
                                  _isFavorito
                                      ? Icons.favorite_rounded
                                      : Icons.favorite_border_rounded,
                                  color: _isFavorito
                                      ? Colors.redAccent
                                      : (isDark
                                          ? Colors.white38
                                          : Colors.black26),
                                  size: 22,
                                ),
                              ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Seta
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: Icon(
                Icons.chevron_right_rounded,
                color: roxo.withOpacity(0.5),
                size: 22,
              ),
            ),
          ],
        ),
      ),
    );
  }
}