import 'package:flutter/material.dart';
import '../screens/detalhe_page.dart';

class ObraCard extends StatelessWidget {
  final String titulo;
  final String descricao;

  const ObraCard({super.key, required this.titulo, required this.descricao});

  @override
  Widget build(BuildContext context) {
    String imagem = 'assets/default.jpg';

    if (titulo == 'One Piece') {
      imagem = 'assets/Onepiecelogo.jpg';
    } else if (titulo == 'Naruto') {
      imagem = 'assets/narutologo.jpg';
    } else if (titulo == 'Attack on Titan') {
      imagem = 'assets/snklogo.jpg';
    }

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
            titulo,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),

          subtitle: Text(descricao),

          trailing: const Icon(Icons.arrow_forward_ios),

          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => DetalhePage(titulo: titulo)),
            );
          },
        ),
      ),
    );
  }
}
