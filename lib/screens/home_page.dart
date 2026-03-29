import 'package:flutter/material.dart';
import '../../widgets/obra_card.dart';
import 'comunidade_page.dart';
import 'downloads_page.dart';

class HomePage extends StatefulWidget {
  final VoidCallback alternarTema;

  const HomePage({super.key, required this.alternarTema});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int paginaAtual = 0;

  final TextEditingController pesquisaController = TextEditingController();

  final List<Map<String, String>> obras = [
    {'titulo': 'Naruto', 'descricao': 'Aventura ninja clássica'},
    {'titulo': 'One Piece', 'descricao': 'Piratas em busca do tesouro'},
    {'titulo': 'Attack on Titan', 'descricao': 'Humanidade contra titãs'},
  ];

  List<Map<String, String>> obrasFiltradas = [];

  @override
  void initState() {
    super.initState();
    obrasFiltradas = obras;
  }

  void filtrarObras(String texto) {
    setState(() {
      obrasFiltradas = obras.where((obra) {
        final titulo = obra['titulo']!.toLowerCase();
        final descricao = obra['descricao']!.toLowerCase();
        final busca = texto.toLowerCase();

        return titulo.contains(busca) || descricao.contains(busca);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final paginas = [
      Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            TextField(
              controller: pesquisaController,
              onChanged: (texto) {
                filtrarObras(texto);
                setState(() {});
              },
              decoration: InputDecoration(
                hintText: 'Pesquisar obra...',
                prefixIcon: const Icon(Icons.search),

                suffixIcon: pesquisaController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          pesquisaController.clear();
                          filtrarObras('');
                          setState(() {});
                        },
                      )
                    : null,

                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
            ),

            if (pesquisaController.text.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 5),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: Theme.of(context).cardColor,
                  boxShadow: [BoxShadow(blurRadius: 4, color: Colors.black12)],
                ),
                child: Column(
                  children: obrasFiltradas.take(3).map((obra) {
                    return ListTile(
                      leading: const Icon(Icons.menu_book),
                      title: Text(obra['titulo']!),
                      subtitle: Text(obra['descricao']!),
                      onTap: () {
                        pesquisaController.text = obra['titulo']!;
                        filtrarObras(obra['titulo']!);
                        setState(() {});
                      },
                    );
                  }).toList(),
                ),
              ),
            const SizedBox(height: 15),

            Expanded(
              child: obrasFiltradas.isEmpty
                  ? const Center(
                      child: Text(
                        'Nenhuma obra encontrada',
                        style: TextStyle(fontSize: 18),
                      ),
                    )
                  : ListView.builder(
                      itemCount: obrasFiltradas.length,
                      itemBuilder: (context, index) {
                        return ObraCard(
                          titulo: obrasFiltradas[index]['titulo']!,
                          descricao: obrasFiltradas[index]['descricao']!,
                        );
                      },
                    ),
            ),
          ],
        ),
      ),

      const ComunidadePage(),

      const DownloadsPage(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Toon Archive'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.dark_mode),
            onPressed: widget.alternarTema,
          ),
        ],
      ),

      body: paginas[paginaAtual],

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: paginaAtual,
        onTap: (index) {
          setState(() {
            paginaAtual = index;
          });
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.chat), label: 'Comunidade'),
          BottomNavigationBarItem(
            icon: Icon(Icons.download),
            label: 'Downloads',
          ),
        ],
      ),
    );
  }
}
