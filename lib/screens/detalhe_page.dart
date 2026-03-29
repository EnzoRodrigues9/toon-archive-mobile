import 'package:flutter/material.dart';
import 'leitura_page.dart';
import 'download_manager.dart';

class DetalhePage extends StatelessWidget {
  final String titulo;

  const DetalhePage({super.key, required this.titulo});

  @override
  Widget build(BuildContext context) {
    final capitulos = List.generate(10, (index) => 'Capítulo ${index + 1}');

    return Scaffold(
      appBar: AppBar(title: Text(titulo)),

      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            const SizedBox(height: 10),

            Text(
              titulo,
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
                            '$titulo - ${capitulos[index]}',
                          );

                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Capítulo baixado')),
                          );
                        },
                      ),

                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => LeituraPage(
                              capitulo: capitulos[index],
                              titulo: titulo,
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
