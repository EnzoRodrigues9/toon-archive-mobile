import 'package:flutter/material.dart';
import 'leitura_page.dart';
import '../services/favoritos_service.dart';
import 'download_manager.dart';
import '../data/biblioteca.dart';

class DetalhePage extends StatefulWidget {
  final String titulo;

  const DetalhePage({super.key, required this.titulo});

  @override
  State<DetalhePage> createState() => _DetalhePageState();
}

class _DetalhePageState extends State<DetalhePage> {
  bool isFavorito = false;

  @override
  void initState() {
    super.initState();
    carregarFavorito();
  }

  Future<void> carregarFavorito() async {
    bool fav = await FavoritosService.isFavorito(widget.titulo);
    setState(() {
      isFavorito = fav;
    });
  }

  Future<void> toggleFavorito() async {
    await FavoritosService.toggleFavorito(widget.titulo);
    setState(() {
      isFavorito = !isFavorito;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Pegando os capítulos reais da biblioteca
    final capitulos = biblioteca[widget.titulo]!.keys.toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.titulo),
        actions: [
          IconButton(
            icon: Icon(
              isFavorito ? Icons.favorite : Icons.favorite_border,
              color: Colors.redAccent,
            ),
            onPressed: toggleFavorito,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Text(
              widget.titulo,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            const Text('Lista de capítulos', style: TextStyle(fontSize: 18)),
            const SizedBox(height: 15),
            Expanded(
              child: ListView.builder(
                itemCount: capitulos.length,
                itemBuilder: (context, index) {
                  return Card(
                    child: ListTile(
                      title: Text(capitulos[index]),
                      trailing: IconButton(
                        icon: const Icon(Icons.download),
                        onPressed: () {
                          DownloadManager.downloads.add(
                            '${widget.titulo} - ${capitulos[index]}',
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Capítulo baixado')),
                          );
                        },
                      ),
                      onTap: () {
                        // Vai para o LeituraPage com o capítulo correto
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => LeituraPage(
                              capitulo: capitulos[index],
                              titulo: widget.titulo,
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
