import 'package:flutter/material.dart';
import '../screens/detalhe_page.dart';
import '../services/favoritos_service.dart';

class ObraCard extends StatefulWidget {
  final String titulo;
  final String descricao;
  final VoidCallback? onFavoritoAlterado;

  const ObraCard({
    super.key,
    required this.titulo,
    required this.descricao,
    this.onFavoritoAlterado,
  });

  @override
  State<ObraCard> createState() => _ObraCardState();
}

class _ObraCardState extends State<ObraCard> {
  bool isFavorito = false;

  @override
  void initState() {
    super.initState();
    carregarFavorito();
  }

  @override
  void didUpdateWidget(covariant ObraCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    carregarFavorito();
  }

  Future<void> carregarFavorito() async {
    final favoritos = await FavoritosService.getFavoritos();
    if (!mounted) return;

    setState(() {
      isFavorito = favoritos.contains(widget.titulo);
    });
  }

  Future<void> toggleFavorito() async {
    await FavoritosService.toggleFavorito(widget.titulo);
    carregarFavorito();

    widget.onFavoritoAlterado?.call();
  }

  @override
  Widget build(BuildContext context) {
    String imagem = 'assets/default.jpg';
    if (widget.titulo == 'One Piece') imagem = 'assets/Onepiecelogo.jpg';
    if (widget.titulo == 'Naruto') imagem = 'assets/narutologo.jpg';
    if (widget.titulo == 'Attack on Titan') imagem = 'assets/snklogo.jpg';

    return Card(
      elevation: 5,
      margin: const EdgeInsets.only(bottom: 15),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: SizedBox(
        height: 90,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 8,
          ),

          //Imagem obra
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.asset(
              imagem,
              width: 130,
              height: 60,
              fit: BoxFit.cover,
            ),
          ),

          title: Text(
            widget.titulo,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),

          subtitle: Text(
            widget.descricao,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),

          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                icon: Icon(
                  isFavorito ? Icons.favorite : Icons.favorite_border,
                  color: Colors.redAccent,
                ),
                onPressed: toggleFavorito,
              ),
              const Icon(Icons.arrow_forward_ios, size: 18),
            ],
          ),

          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => DetalhePage(titulo: widget.titulo),
              ),
            ).then((_) {
              carregarFavorito();
              widget.onFavoritoAlterado?.call();
            });
          },
        ),
      ),
    );
  }
}
