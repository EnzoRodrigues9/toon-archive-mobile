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
  PageController? controller;
  final TextEditingController comentarioController = TextEditingController();
  final Map<String, List<String>> comentariosPorCapitulo = {};
  String capituloAtual = '';

  @override
  void initState() {
    super.initState();
    carregarCapituloInicial();
  }

  @override
  void dispose() {
    controller?.dispose();
    comentarioController.dispose();
    super.dispose();
  }

  Future<void> carregarCapituloInicial() async {
    final prefs = await SharedPreferences.getInstance();
    final salvo = prefs.getString('${widget.titulo}_ultimo_capitulo');

    if (!mounted) return;

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
    if (comentarioController.text.trim().isNotEmpty) {
      setState(() {
        comentariosPorCapitulo.putIfAbsent(chaveComentario, () => []);
        comentariosPorCapitulo[chaveComentario]!.add(
          comentarioController.text.trim(),
        );
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
                    comentarioController.text.trim();
              });
              comentarioController.clear();
              Navigator.pop(context);
            },
            child: const Text('Salvar'),
          ),
          TextButton(
            onPressed: () {
              comentarioController.clear();
              Navigator.pop(context);
            },
            child: const Text('Cancelar'),
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
      controller?.dispose();
      controller = PageController(initialPage: 0);
    });
    salvarCapitulo();
  }

  void proximoCapitulo() {
    final index = capitulos.indexOf(capituloAtual);
    if (index < capitulos.length - 1) {
      mudarCapitulo(capitulos[index + 1]);
    }
  }

  void capituloAnterior() {
    final index = capitulos.indexOf(capituloAtual);
    if (index > 0) {
      mudarCapitulo(capitulos[index - 1]);
    }
  }

  Widget comentariosWidget() {
    final roxo = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      color: isDark ? const Color(0xFF140F1F) : Colors.white,
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 60,
            height: 4,
            decoration: BoxDecoration(
              color: roxo.withOpacity(0.35),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Comentários',
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color: roxo,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: comentarioController,
              decoration: InputDecoration(
                hintText: 'Digite um comentário...',
                suffixIcon: IconButton(
                  icon: Icon(Icons.send_rounded, color: roxo),
                  onPressed: adicionarComentario,
                ),
              ),
            ),
          ),
          ...comentarios.asMap().entries.map((entry) {
            final index = entry.key;
            final comentario = entry.value;

            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF20172C)
                    : const Color(0xFFF7F2FF),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: roxo.withOpacity(0.10)),
              ),
              child: ListTile(
                title: Text(comentario),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_rounded),
                      onPressed: () => editarComentario(index),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_rounded),
                      onPressed: () => excluirComentario(index),
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 18),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (controller == null || capituloAtual.isEmpty) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final paginas = getPaginas();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Roxo muda conforme o tema:
    // light = mais escuro
    // dark = mais claro
    final Color roxoLeitura = isDark
        ? const Color(0xFFB388FF)
        : const Color(0xFF6D28D9);

    return Scaffold(
      backgroundColor: isDark ? Colors.black : const Color(0xFFF7F4FB),
      appBar: AppBar(
        backgroundColor: roxoLeitura,
        foregroundColor: Colors.white,
        elevation: 0,

        leadingWidth: 130,
        leading: TextButton.icon(
          style: TextButton.styleFrom(padding: const EdgeInsets.only(left: 8)),
          onPressed: () {
            final index = capitulos.indexOf(capituloAtual);

            if (index > 0) {
              capituloAnterior();
            } else {
              Navigator.pop(context);
            }
          },
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          label: const Text('Anterior', style: TextStyle(color: Colors.white)),
        ),

        title: Text(
          capituloAtual,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        centerTitle: true,

        actions: [
          const SizedBox(width: 12),

          IconButton(
            tooltip: 'Voltar para obra',
            icon: const Icon(Icons.home_rounded),
            onPressed: () => Navigator.pop(context),
          ),

          const SizedBox(width: 6),

          // 🔁 MODO LEITURA
          IconButton(
            tooltip: modoClique ? 'Modo toque' : 'Modo rolagem',
            icon: Icon(
              modoClique ? Icons.swipe_rounded : Icons.touch_app_rounded,
            ),
            onPressed: () => setState(() => modoClique = !modoClique),
          ),

          const SizedBox(width: 6),

          // 👉 PRÓXIMO CAPÍTULO
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: TextButton(
              onPressed: proximoCapitulo,
              child: const Row(
                children: [
                  Text('Próximo', style: TextStyle(color: Colors.white)),
                  SizedBox(width: 4),
                  Icon(Icons.arrow_forward, color: Colors.white),
                ],
              ),
            ),
          ),
        ],
      ),
      body: modoClique
          ? PageView.builder(
              key: ValueKey(capituloAtual),
              controller: controller,
              itemCount: paginas.length + 1,
              itemBuilder: (context, index) {
                if (index < paginas.length) {
                  return GestureDetector(
                    onTapUp: (details) {
                      final largura = MediaQuery.of(context).size.width;
                      final posicao = details.localPosition.dx;

                      if (posicao > largura / 2) {
                        if (index < paginas.length - 1) {
                          controller!.nextPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        } else {
                          controller!.animateToPage(
                            paginas.length,
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        }
                      } else {
                        if (index > 0) {
                          controller!.previousPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        } else if (capitulos.indexOf(capituloAtual) > 0) {
                          capituloAnterior();
                        }
                      }
                    },
                    child: Container(
                      color: isDark ? Colors.black : const Color(0xFFF2F2F2),
                      child: Center(
                        child: InteractiveViewer(
                          minScale: 1,
                          maxScale: 4,
                          child: Image.asset(
                            paginas[index],
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) {
                              return const Center(
                                child: Text('Erro ao carregar página'),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  );
                } else {
                  return GestureDetector(
                    onHorizontalDragEnd: (details) {
                      if ((details.primaryVelocity ?? 0) < 0) {
                        proximoCapitulo();
                      } else if ((details.primaryVelocity ?? 0) > 0) {
                        capituloAnterior();
                      }
                    },
                    onTapUp: (details) {
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
                  return Container(
                    color: isDark ? Colors.black : const Color(0xFFF2F2F2),
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Image.asset(
                        paginas[index],
                        width: double.infinity,
                        fit: BoxFit.fitWidth,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            height: 220,
                            alignment: Alignment.center,
                            child: const Text('Erro ao carregar página'),
                          );
                        },
                      ),
                    ),
                  );
                }
                return comentariosWidget();
              },
            ),
    );
  }
}
