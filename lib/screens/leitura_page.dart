import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/biblioteca.dart';

class LeituraPage extends StatefulWidget {
  final String capitulo;
  final String titulo;

  const LeituraPage({super.key, required this.capitulo, required this.titulo});

  @override
  State<LeituraPage> createState() => _LeituraPageState();
}

class _LeituraPageState extends State<LeituraPage> {
  bool modoClique = false;
  late PageController controller;
  final TextEditingController comentarioController = TextEditingController();
  Map<String, List<String>> comentariosPorCapitulo = {};
  late String capituloAtual;

  @override
  void initState() {
    super.initState();
    carregarCapituloInicial();
  }

  Future<void> carregarCapituloInicial() async {
    final prefs = await SharedPreferences.getInstance();
    String? salvo = prefs.getString('${widget.titulo}_ultimo_capitulo');
    setState(() {
      capituloAtual = widget.capitulo.isNotEmpty
          ? widget.capitulo
          : (salvo ?? 'Capítulo 1');
      controller = PageController(initialPage: 0);
    });
  }

  Future<void> salvarCapitulo() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('${widget.titulo}_ultimo_capitulo', capituloAtual);
  }

  List<String> get capitulos => biblioteca[widget.titulo]!.keys.toList();
  List<String> getPaginas() =>
      biblioteca[widget.titulo]?[capituloAtual] ?? ['assets/default.jpg'];
  String get chaveComentario => '${widget.titulo}-$capituloAtual';
  List<String> get comentarios => comentariosPorCapitulo[chaveComentario] ?? [];

  void adicionarComentario() {
    if (comentarioController.text.isNotEmpty) {
      setState(() {
        comentariosPorCapitulo.putIfAbsent(chaveComentario, () => []);
        comentariosPorCapitulo[chaveComentario]!.add(comentarioController.text);
        comentarioController.clear();
      });
    }
  }

  void editarComentario(int index) {
    comentarioController.text = comentarios[index];
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Editar comentário'),
        content: TextField(controller: comentarioController),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                comentariosPorCapitulo[chaveComentario]![index] =
                    comentarioController.text;
              });
              comentarioController.clear();
              Navigator.pop(context);
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }

  void excluirComentario(int index) {
    setState(() {
      comentariosPorCapitulo[chaveComentario]!.removeAt(index);
    });
  }

  void mudarCapitulo(String novoCapitulo) {
    setState(() {
      capituloAtual = novoCapitulo;
      controller.dispose();
      controller = PageController(initialPage: 0);
    });
    salvarCapitulo();
  }

  void proximoCapitulo() {
    int index = capitulos.indexOf(capituloAtual);
    if (index < capitulos.length - 1) {
      mudarCapitulo(capitulos[index + 1]);
    }
  }

  void capituloAnterior() {
    int index = capitulos.indexOf(capituloAtual);
    if (index > 0) {
      mudarCapitulo(capitulos[index - 1]);
    }
  }

  Widget comentariosWidget() {
    return Column(
      children: [
        const Divider(),
        const Text(
          'Comentários',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        Padding(
          padding: const EdgeInsets.all(8),
          child: TextField(
            controller: comentarioController,
            decoration: InputDecoration(
              hintText: 'Digite um comentário...',
              suffixIcon: IconButton(
                icon: const Icon(Icons.send),
                onPressed: adicionarComentario,
              ),
            ),
          ),
        ),
        ...comentarios.asMap().entries.map((entry) {
          int index = entry.key;
          String comentario = entry.value;
          return ListTile(
            title: Text(comentario),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () => editarComentario(index),
                ),
                IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () => excluirComentario(index),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    List<String> paginas = getPaginas();
    final bool isModoClaro = Theme.of(context).brightness == Brightness.light;
    final Color textoBotao = isModoClaro ? Colors.black87 : Colors.white;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            TextButton(
              onPressed: capituloAnterior,
              child: Text('Anterior', style: TextStyle(color: textoBotao)),
            ),
            Expanded(
              child: Center(
                child: Text(capituloAtual, style: TextStyle(color: textoBotao)),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(modoClique ? Icons.swipe : Icons.touch_app),
            onPressed: () => setState(() => modoClique = !modoClique),
          ),
          const SizedBox(width: 12),
          TextButton(
            onPressed: proximoCapitulo,
            child: Row(
              children: [
                Text('Próximo', style: TextStyle(color: textoBotao)),
                Icon(Icons.arrow_forward, color: textoBotao),
              ],
            ),
          ),
        ],
      ),
      body: modoClique
          ? PageView.builder(
              key: ValueKey(capituloAtual),
              controller: controller,
              itemCount: paginas.length + 1, // +1 para comentários
              itemBuilder: (context, index) {
                if (index < paginas.length) {
                  // Páginas do capítulo
                  return GestureDetector(
                    onTapUp: (details) {
                      final largura = MediaQuery.of(context).size.width;
                      final posicao = details.localPosition.dx;

                      if (posicao > largura / 2) {
                        if (index < paginas.length - 1) {
                          controller.nextPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        } else {
                          // Última página -> ir para comentários
                          controller.animateToPage(
                            paginas.length,
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        }
                      } else {
                        if (index > 0) {
                          controller.previousPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        } else {
                          // Primeira página -> capítulo anterior
                          if (capitulos.indexOf(capituloAtual) > 0) {
                            capituloAnterior();
                          }
                        }
                      }
                    },
                    child: Center(
                      child: InteractiveViewer(
                        child: Image.asset(paginas[index], fit: BoxFit.contain),
                      ),
                    ),
                  );
                } else {
                  // Página de comentários
                  return GestureDetector(
                    onHorizontalDragEnd: (details) {
                      if (details.primaryVelocity! < 0) {
                        proximoCapitulo();
                      } else if (details.primaryVelocity! > 0) {
                        capituloAnterior();
                      }
                    },
                    onTapUp: (details) {
                      // Clique na aba de comentários -> passa para o próximo capítulo
                      if (details.localPosition.dx >
                          MediaQuery.of(context).size.width / 2) {
                        proximoCapitulo();
                      } else {
                        capituloAnterior();
                      }
                    },
                    child: SingleChildScrollView(child: comentariosWidget()),
                  );
                }
              },
            )
          : ListView.builder(
              itemCount: paginas.length + 1,
              itemBuilder: (context, index) {
                if (index < paginas.length) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Image.asset(
                      paginas[index],
                      width: double.infinity,
                      fit: BoxFit.fitWidth,
                    ),
                  );
                }
                return comentariosWidget();
              },
            ),
    );
  }
}
