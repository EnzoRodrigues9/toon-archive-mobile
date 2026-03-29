import 'package:flutter/material.dart';

class ComunidadePage extends StatefulWidget {
  const ComunidadePage({super.key});

  @override
  State<ComunidadePage> createState() => _ComunidadePageState();
}

class _ComunidadePageState extends State<ComunidadePage> {
  final TextEditingController controller = TextEditingController();

  List<Map<String, dynamic>> mensagens = [
    {'texto': 'Alguém já leu o capítulo novo?', 'minha': false},
    {'texto': 'One Piece tá muito bom!', 'minha': false},
    {
      'texto': 'Naruto clássico sempre será melhor que o Shippuden',
      'minha': false,
    },
  ];

  void enviarMensagem() {
    if (controller.text.isNotEmpty) {
      setState(() {
        mensagens.add({'texto': controller.text, 'minha': true});
        controller.clear();
      });
    }
  }

  void excluirMensagem(int index) {
    setState(() {
      mensagens.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: mensagens.length,
            itemBuilder: (context, index) {
              final msg = mensagens[index];

              return Align(
                alignment: msg['minha']
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeInOut,
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: msg['minha']
                        ? (isDark
                              ? Colors.green.shade700
                              : Colors.lightGreen.shade300)
                        : (isDark
                              ? Colors.grey.shade800
                              : Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          msg['texto'],
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                      ),

                      if (msg['minha'])
                        IconButton(
                          icon: Icon(
                            Icons.delete,
                            size: 18,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                          onPressed: () => excluirMensagem(index),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),

        Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  decoration: InputDecoration(
                    hintText: 'Digite sua mensagem...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                ),
              ),

              IconButton(
                icon: const Icon(Icons.send),
                onPressed: enviarMensagem,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
