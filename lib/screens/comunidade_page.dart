import 'package:flutter/material.dart';
import 'grupo_chat_page.dart';

class ComunidadePage extends StatelessWidget {
  const ComunidadePage({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final roxo = Theme.of(context).colorScheme.primary;
    final roxoSecundario = Theme.of(context).colorScheme.secondary;

    final List<Map<String, dynamic>> grupos = [
      {
        'nome': 'One Piece',
        'descricao':
            'Grupo para fãs de One Piece discutirem capítulos e teorias',
        'icone': Icons.sailing_rounded,
        'membros': '12.4 mil membros',
        'mensagem': 'Capítulo novo insano demais',
      },
      {
        'nome': 'Naruto',
        'descricao': 'Conversas sobre Naruto clássico, Shippuden e Boruto',
        'icone': Icons.auto_awesome_rounded,
        'membros': '8.9 mil membros',
        'mensagem': 'Naruto clássico ainda é cinema',
      },
      {
        'nome': 'Attack on Titan',
        'descricao': 'Teorias, análises e debates sobre Shingeki no Kyojin',
        'icone': Icons.shield_rounded,
        'membros': '6.1 mil membros',
        'mensagem': 'O final divide opiniões até hoje',
      },
      {
        'nome': 'Jujutsu Kaisen',
        'descricao': 'Batalhas, poderes e discussões sobre JJK',
        'icone': Icons.flash_on_rounded,
        'membros': '7.3 mil membros',
        'mensagem': 'Gojo ainda é o favorito de muita gente',
      },
      {
        'nome': 'Kagurabachi',
        'descricao': 'Grupo para fãs acompanharem os capítulos e hype da obra',
        'icone': Icons.local_fire_department_rounded,
        'membros': '3.2 mil membros',
        'mensagem': 'Essa obra cresceu rápido demais',
      },
    ];

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF140F1F), const Color(0xFF1B132B)]
              : [const Color(0xFFF4EEFF), const Color(0xFFEDE4FF)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  gradient: LinearGradient(
                    colors: [
                      roxo.withOpacity(0.96),
                      roxoSecundario.withOpacity(0.90),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: roxo.withOpacity(0.24),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Row(
                  children: [
                    Icon(Icons.groups_rounded, color: Colors.white, size: 28),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Comunidades',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            'Entre em grupos e converse com outros fãs',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 16),
                itemCount: grupos.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final grupo = grupos[index];

                  return InkWell(
                    borderRadius: BorderRadius.circular(22),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              GrupoChatPage(nomeGrupo: grupo['nome']),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF20172C)
                            : Colors.white.withOpacity(0.92),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: roxo.withOpacity(0.12)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(
                              isDark ? 0.14 : 0.05,
                            ),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 62,
                            height: 62,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(18),
                              gradient: LinearGradient(
                                colors: [
                                  roxo.withOpacity(0.95),
                                  roxoSecundario.withOpacity(0.85),
                                ],
                              ),
                            ),
                            child: Icon(
                              grupo['icone'],
                              color: Colors.white,
                              size: 30,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  grupo['nome'],
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                    color: isDark
                                        ? Colors.white
                                        : Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  grupo['descricao'],
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13,
                                    height: 1.35,
                                    color: isDark
                                        ? Colors.white70
                                        : Colors.black54,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.people_alt_rounded,
                                      size: 16,
                                      color: roxo,
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      grupo['membros'],
                                      style: TextStyle(
                                        color: roxo,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12.5,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  grupo['mensagem'],
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: isDark
                                        ? Colors.white60
                                        : Colors.black45,
                                    fontSize: 12.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.arrow_forward_ios_rounded,
                            color: roxo,
                            size: 18,
                          ),
                        ],
                      ),
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
