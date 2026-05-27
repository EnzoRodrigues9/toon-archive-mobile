import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class GrupoChatPage extends StatefulWidget {
  final String nomeGrupo;
  const GrupoChatPage({super.key, required this.nomeGrupo});
  @override
  State<GrupoChatPage> createState() => _GrupoChatPageState();
}

class _GrupoChatPageState extends State<GrupoChatPage> {
  final _controller = TextEditingController();
  late List<Map<String, dynamic>> _mensagens;

  @override
  void initState() { super.initState(); _mensagens = _iniciais(widget.nomeGrupo); }
  @override
  void dispose() { _controller.dispose(); super.dispose(); }

  List<Map<String, dynamic>> _iniciais(String grupo) {
    const m = {
      'One Piece':       [['LuffyBR','Alguém viu o capítulo mais recente?'],['ZoroFan','O Oda simplesmente não erra'],['NamiChan','Essa saga tá muito boa']],
      'Naruto':          [['Shinobi_22','Naruto clássico ainda é meu favorito'],['UchihaBR','Itachi continua sendo incrível']],
      'Attack on Titan': [['ScoutBR','A trilha sonora é absurda'],['MikasaFan','Até hoje penso no final']],
      'Jujutsu Kaisen':  [['GojoBR','Gojo é simplesmente lendário'],['Yuji_Fan','As lutas são muito boas']],
      'Kagurabachi':     [['BladeFan','O hype cresceu rápido'],['BachiBR','Tô gostando bastante da arte']],
    };
    final lista = m[grupo] ?? [['Fã', 'Bem-vindo ao grupo!']];
    return lista.map<Map<String, dynamic>>((e) => {'usuario': e[0], 'texto': e[1], 'minha': false, 'data': DateTime.now()}).toList();
  }

  void _enviar() {
    if (_controller.text.trim().isEmpty) return;
    setState(() {
      _mensagens.add({'usuario': 'Você', 'texto': _controller.text.trim(), 'minha': true, 'data': DateTime.now()});
      _controller.clear();
    });
  }

  void _editar(int i) {
    _controller.text = _mensagens[i]['texto'];
    showDialog(context: context, builder: (_) => AlertDialog(
      title: const Text('Editar mensagem'),
      content: TextField(controller: _controller, autofocus: true),
      actions: [
        TextButton(onPressed: () { if (_controller.text.trim().isNotEmpty) setState(() => _mensagens[i]['texto'] = _controller.text.trim()); _controller.clear(); Navigator.pop(context); }, child: const Text('Salvar')),
        TextButton(onPressed: () { _controller.clear(); Navigator.pop(context); }, child: const Text('Cancelar')),
      ],
    ));
  }

  void _excluir(int i) => setState(() => _mensagens.removeAt(i));

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final roxo   = isDark ? const Color(0xFF9F67FA) : const Color(0xFF7C3AED);
    final fundo  = isDark ? const Color(0xFF0F0A1E) : const Color(0xFFF5F3FF);

    return Scaffold(
      backgroundColor: fundo,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1A1030) : roxo,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text(widget.nomeGrupo, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
      ),
      body: Column(children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(14),
            itemCount: _mensagens.length,
            itemBuilder: (_, i) {
              final msg = _mensagens[i];
              final minha = msg['minha'] == true;
              return Align(
                alignment: minha ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 300),
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: minha
                        ? (isDark ? const Color(0xFF5B21B6) : const Color(0xFF7C3AED))
                        : (isDark ? const Color(0xFF1A1030) : Colors.white),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18), topRight: const Radius.circular(18),
                      bottomLeft: Radius.circular(minha ? 18 : 4),
                      bottomRight: Radius.circular(minha ? 4 : 18),
                    ),
                    border: Border.all(color: roxo.withOpacity(minha ? 0 : 0.14)),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 6, offset: const Offset(0, 2))],
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    if (!minha) Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(msg['usuario'], style: TextStyle(color: roxo, fontWeight: FontWeight.w800, fontSize: 12)),
                    ),
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      Flexible(child: Text(msg['texto'], style: TextStyle(color: minha ? Colors.white : (isDark ? Colors.white : Colors.black87)))),
                      if (minha) ...[
                        const SizedBox(width: 4),
                        GestureDetector(onTap: () => _editar(i), child: Icon(Icons.edit_rounded, size: 16, color: Colors.white.withOpacity(0.7))),
                        const SizedBox(width: 2),
                        GestureDetector(onTap: () => _excluir(i), child: Icon(Icons.delete_rounded, size: 16, color: Colors.white.withOpacity(0.7))),
                      ],
                    ]),
                    const SizedBox(height: 4),
                    Align(
                      alignment: Alignment.bottomRight,
                      child: Text(DateFormat('HH:mm').format(msg['data']), style: TextStyle(fontSize: 10, color: minha ? Colors.white60 : (isDark ? Colors.white38 : Colors.black38))),
                    ),
                  ]),
                ),
              );
            },
          ),
        ),
        // Input
        SafeArea(
          top: false,
          child: Container(
            padding: EdgeInsets.fromLTRB(12, 8, 12, MediaQuery.of(context).viewInsets.bottom + 8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1A1030) : Colors.white,
              border: Border(top: BorderSide(color: roxo.withOpacity(0.12))),
            ),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                  decoration: InputDecoration(
                    hintText: 'Digite sua mensagem...',
                    hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.black38, fontSize: 14),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF231840) : const Color(0xFFF5F3FF),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide(color: roxo, width: 1.2)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _enviar,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [roxo, const Color(0xFF9F67FA)]),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                ),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}