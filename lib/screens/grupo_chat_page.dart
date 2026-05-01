import 'package:flutter/material.dart';

class GrupoChatPage extends StatefulWidget {
  final String nomeGrupo;

  const GrupoChatPage({super.key, required this.nomeGrupo});

  @override
  State<GrupoChatPage> createState() => _GrupoChatPageState();
}

class _GrupoChatPageState extends State<GrupoChatPage> {
  final TextEditingController controller = TextEditingController();

  late List<Map<String, dynamic>> mensagens;

  @override
  void initState() {
    super.initState();
    mensagens = _mensagensIniciais(widget.nomeGrupo);
  }

  List<Map<String, dynamic>> _mensagensIniciais(String grupo) {
    switch (grupo) {
      case 'One Piece':
        return [
          {
            'usuario': 'LuffyBR',
            'texto': 'Alguém viu o capítulo mais recente?',
            'minha': false,
          },
          {
            'usuario': 'ZoroFan',
            'texto': 'O Oda simplesmente não erra',
            'minha': false,
          },
          {
            'usuario': 'NamiChan',
            'texto': 'Essa saga tá muito boa',
            'minha': false,
          },
        ];
      case 'Naruto':
        return [
          {
            'usuario': 'Shinobi_22',
            'texto': 'Naruto clássico ainda é meu favorito',
            'minha': false,
          },
          {
            'usuario': 'UchihaBR',
            'texto': 'Itachi continua sendo um dos melhores personagens',
            'minha': false,
          },
        ];
      case 'Attack on Titan':
        return [
          {
            'usuario': 'ScoutBR',
            'texto': 'A trilha sonora desse anime é absurda',
            'minha': false,
          },
          {
            'usuario': 'MikasaFan',
            'texto': 'Até hoje penso no final',
            'minha': false,
          },
        ];
      case 'Jujutsu Kaisen':
        return [
          {
            'usuario': 'GojoBR',
            'texto': 'Gojo é simplesmente lendário',
            'minha': false,
          },
          {
            'usuario': 'Yuji_Fan',
            'texto': 'As lutas são muito boas',
            'minha': false,
          },
        ];
      case 'Kagurabachi':
        return [
          {
            'usuario': 'BladeFan',
            'texto': 'O hype dessa obra cresceu rápido',
            'minha': false,
          },
          {
            'usuario': 'BachiBR',
            'texto': 'Tô gostando bastante da arte',
            'minha': false,
          },
        ];
      default:
        return [
          {'usuario': 'Fã', 'texto': 'Bem-vindo ao grupo!', 'minha': false},
        ];
    }
  }

  void enviarMensagem() {
    if (controller.text.trim().isNotEmpty) {
      setState(() {
        mensagens.add({
          'usuario': 'Você',
          'texto': controller.text.trim(),
          'minha': true,
        });
        controller.clear();
      });
    }
  }

  void editarMensagem(int index) {
    controller.text = mensagens[index]['texto'];

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Editar mensagem'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Digite a mensagem'),
        ),
        actions: [
          TextButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                setState(() {
                  mensagens[index]['texto'] = controller.text.trim();
                });
              }
              controller.clear();
              Navigator.pop(context);
            },
            child: const Text('Salvar'),
          ),
          TextButton(
            onPressed: () {
              controller.clear();
              Navigator.pop(context);
            },
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );
  }

  void excluirMensagem(int index) {
    setState(() {
      mensagens.removeAt(index);
    });
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final roxo = Theme.of(context).colorScheme.primary;
    final roxoSecundario = Theme.of(context).colorScheme.secondary;

    return Scaffold(
      appBar: AppBar(title: Text(widget.nomeGrupo), centerTitle: true),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [const Color(0xFF140F1F), const Color(0xFF1B132B)]
                : [const Color(0xFFF4EEFF), const Color(0xFFEDE4FF)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: LinearGradient(
                  colors: [
                    roxo.withOpacity(0.95),
                    roxoSecundario.withOpacity(0.88),
                  ],
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.forum_rounded, color: Colors.white),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Grupo de fãs de ${widget.nomeGrupo}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: mensagens.length,
                itemBuilder: (context, index) {
                  final msg = mensagens[index];
                  final bool minha = msg['minha'] == true;

                  return Align(
                    alignment: minha
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 320),
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: minha
                            ? (isDark
                                  ? const Color(0xFF7C4DFF)
                                  : const Color(0xFFD9C2FF))
                            : (isDark
                                  ? const Color(0xFF2B223B)
                                  : const Color(0xFFF1E8FF)),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: roxo.withOpacity(0.12)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (!minha)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 5),
                              child: Text(
                                msg['usuario'],
                                style: TextStyle(
                                  color: roxo,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12.5,
                                ),
                              ),
                            ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  msg['texto'],
                                  style: TextStyle(
                                    color: isDark
                                        ? Colors.white
                                        : Colors.black87,
                                  ),
                                ),
                              ),
                              if (minha) ...[
                                IconButton(
                                  icon: Icon(
                                    Icons.edit_rounded,
                                    size: 18,
                                    color: isDark
                                        ? Colors.white
                                        : Colors.black87,
                                  ),
                                  onPressed: () => editarMensagem(index),
                                ),
                                IconButton(
                                  icon: Icon(
                                    Icons.delete_rounded,
                                    size: 18,
                                    color: isDark
                                        ? Colors.white
                                        : Colors.black87,
                                  ),
                                  onPressed: () => excluirMensagem(index),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  10,
                  0,
                  10,
                  MediaQuery.of(context).viewInsets.bottom + 10,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: controller,
                        decoration: const InputDecoration(
                          hintText: 'Digite sua mensagem...',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: roxo,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: IconButton(
                        icon: const Icon(
                          Icons.send_rounded,
                          color: Colors.white,
                        ),
                        onPressed: enviarMensagem,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
