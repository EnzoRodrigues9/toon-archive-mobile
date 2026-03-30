import 'package:flutter/material.dart';
import '../screens/detalhe_page.dart';
import '../services/favoritos_service.dart';

class ObraCard extends StatefulWidget {
  final String titulo;
  final String descricao;
  final VoidCallback? onFavoritoAlterado; // callback para sincronizar HomePage

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
    // Recarrega o favorito se o widget foi atualizado
    carregarFavorito();
  }

  Future<void> carregarFavorito() async {
    final favoritos = await FavoritosService.getFavoritos();
    setState(() {
      isFavorito = favoritos.contains(widget.titulo);
    });
  }

  Future<void> toggleFavorito() async {
    await FavoritosService.toggleFavorito(widget.titulo);
    // Atualiza o estado após alterar
    carregarFavorito();

    // Notifica a HomePage para atualizar a lista
    if (widget.onFavoritoAlterado != null) {
      widget.onFavoritoAlterado!();
    }
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
            vertical: 10,
          ),
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.asset(
              imagem,
              width: 150,
              height: 150,
              fit: BoxFit.contain,
            ),
          ),
          title: Text(
            widget.titulo,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text(widget.descricao),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(
                  isFavorito ? Icons.favorite : Icons.favorite_border,
                  color: Colors.redAccent,
                ),
                onPressed: toggleFavorito,
              ),
              const Icon(Icons.arrow_forward_ios),
            ],
          ),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => DetalhePage(titulo: widget.titulo),
              ),
            ).then((_) {
              // Atualiza o favorito ao voltar da página de detalhe
              carregarFavorito();
              if (widget.onFavoritoAlterado != null)
                widget.onFavoritoAlterado!();
            });
          },
        ),
      ),
    );
  }
}
