import 'package:flutter/material.dart';

class LeituraPage extends StatefulWidget {
  final String capitulo;
  final String titulo;

  const LeituraPage({super.key, required this.capitulo, required this.titulo});

  @override
  State<LeituraPage> createState() => _LeituraPageState();
}

class _LeituraPageState extends State<LeituraPage> {
  bool modoClique = false;
  final PageController controller = PageController();

  @override
  Widget build(BuildContext context) {
    List<String> paginas = [];

    if (widget.titulo == 'One Piece' && widget.capitulo == 'Capítulo 1') {
      paginas = ['assets/onepiece1.jpg', 'assets/onepiece2.jpg'];
    } else if (widget.titulo == 'One Piece' &&
        widget.capitulo == 'Capítulo 2') {
      paginas = ['assets/onepiece3.jpg', 'assets/onepiece4.jpg'];
    } else if (widget.titulo == 'Naruto' && widget.capitulo == 'Capítulo 1') {
      paginas = ['assets/naruto1.jpg', 'assets/naruto2.jpg'];
    } else if (widget.titulo == 'Attack on Titan' &&
        widget.capitulo == 'Capítulo 1') {
      paginas = ['assets/snk1.jpg', 'assets/snk2.jpg'];
    } else {
      paginas = ['assets/default.jpg'];
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.capitulo),
        actions: [
          IconButton(
            icon: Icon(modoClique ? Icons.swipe : Icons.touch_app),
            onPressed: () {
              setState(() {
                modoClique = !modoClique;
              });
            },
          ),
        ],
      ),

      body: modoClique
          ? GestureDetector(
              onTapUp: (details) {
                final largura = MediaQuery.of(context).size.width;
                final posicao = details.localPosition.dx;

                if (posicao > largura / 2) {
                  controller.nextPage(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                } else {
                  controller.previousPage(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                }
              },
              child: PageView.builder(
                controller: controller,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: paginas.length,
                itemBuilder: (context, index) {
                  return Center(
                    child: InteractiveViewer(
                      child: Image.asset(paginas[index], fit: BoxFit.contain),
                    ),
                  );
                },
              ),
            )
          : ListView.builder(
              itemCount: paginas.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Image.asset(
                    paginas[index],
                    width: double.infinity,
                    fit: BoxFit.fitWidth,
                  ),
                );
              },
            ),
    );
  }
}
