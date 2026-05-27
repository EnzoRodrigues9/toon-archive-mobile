import 'package:flutter/material.dart';
import 'grupo_chat_page.dart';

class ComunidadePage extends StatelessWidget {
  const ComunidadePage({super.key});

  static const _grupos = [
    {'nome': 'One Piece',       'desc': 'Grupo para fãs discutirem capítulos e teorias',        'icone': Icons.sailing_rounded,                'membros': '12.4 mil', 'msg': 'Capítulo novo insano demais'},
    {'nome': 'Naruto',          'desc': 'Conversas sobre Naruto clássico, Shippuden e Boruto',   'icone': Icons.auto_awesome_rounded,            'membros': '8.9 mil',  'msg': 'Naruto clássico ainda é cinema'},
    {'nome': 'Attack on Titan', 'desc': 'Teorias, análises e debates sobre Shingeki no Kyojin', 'icone': Icons.shield_rounded,                  'membros': '6.1 mil',  'msg': 'O final divide opiniões até hoje'},
    {'nome': 'Jujutsu Kaisen',  'desc': 'Batalhas, poderes e discussões sobre JJK',             'icone': Icons.flash_on_rounded,                'membros': '7.3 mil',  'msg': 'Gojo ainda é o favorito'},
    {'nome': 'Kagurabachi',     'desc': 'Acompanhe os capítulos e o hype da obra',              'icone': Icons.local_fire_department_rounded,   'membros': '3.2 mil',  'msg': 'Essa obra cresceu rápido demais'},
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final roxo   = isDark ? const Color(0xFF9F67FA) : const Color(0xFF7C3AED);
    final fundo  = isDark ? const Color(0xFF0F0A1E) : const Color(0xFFF5F3FF);
    final card   = isDark ? const Color(0xFF1A1030) : Colors.white;

    return Container(
      color: fundo,
      child: SafeArea(
        child: Column(children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark ? [const Color(0xFF1A1030), const Color(0xFF2D1B5E)] : [const Color(0xFF7C3AED), const Color(0xFF9F67FA)],
              ),
            ),
            child: Row(children: [
              const Icon(Icons.groups_rounded, color: Colors.white, size: 26),
              const SizedBox(width: 10),
              const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Comunidades', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
                Text('Converse com outros fãs', style: TextStyle(color: Colors.white60, fontSize: 11)),
              ]),
            ]),
          ),
          // Lista
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(14),
              itemCount: _grupos.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) {
                final g = _grupos[i];
                return Container(
                  decoration: BoxDecoration(
                    color: card, borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: roxo.withOpacity(0.12)),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.14 : 0.05), blurRadius: 10, offset: const Offset(0, 3))],
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => GrupoChatPage(nomeGrupo: g['nome'] as String))),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(children: [
                        Container(
                          width: 56, height: 56,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            gradient: LinearGradient(colors: [roxo, const Color(0xFF9F67FA)]),
                          ),
                          child: Icon(g['icone'] as IconData, color: Colors.white, size: 26),
                        ),
                        const SizedBox(width: 14),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(g['nome'] as String, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: isDark ? Colors.white : Colors.black87)),
                          const SizedBox(height: 3),
                          Text(g['desc'] as String, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : Colors.black54, height: 1.3)),
                          const SizedBox(height: 6),
                          Row(children: [
                            Icon(Icons.people_alt_rounded, size: 14, color: roxo),
                            const SizedBox(width: 4),
                            Text(g['membros'] as String, style: TextStyle(color: roxo, fontWeight: FontWeight.w700, fontSize: 12)),
                          ]),
                        ])),
                        Icon(Icons.chevron_right_rounded, color: roxo.withOpacity(0.6)),
                      ]),
                    ),
                  ),
                );
              },
            ),
          ),
        ]),
      ),
    );
  }
}