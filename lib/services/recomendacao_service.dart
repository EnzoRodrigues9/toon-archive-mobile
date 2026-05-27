import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/obra.dart';
import '../repositories/favoritos_repository.dart';
import '../repositories/obras_repository.dart';
import '../repositories/generos_repository.dart';
import 'package:flutter/foundation.dart';

/// Recomendação local — sem API externa, sem custo, funciona offline.
///
/// ALGORITMO:
///   1. Coleta os gêneros das obras favoritadas (perfil do usuário)
///   2. Para cada obra candidata, calcula quantos gêneros coincidem
///   3. Usa o genero principal da obra como fator adicional
///   4. Normaliza o score entre 0.0 e 1.0
///   5. Retorna as topN obras com maior pontuação
class RecomendacaoService {
  RecomendacaoService._();
  static final RecomendacaoService instance = RecomendacaoService._();

  final _favoritosRepo = FavoritosRepository.instance;
  final _obrasRepo     = ObrasRepository.instance;
  final _generosRepo   = GenerosRepository.instance;

  Future<List<ObraRecomendada>> recomendar({
    required String usuarioId,
    int topN = 5,
  }) async {
    try {
      // 1. Favoritos do usuário
      final favoritos = await _favoritosRepo.listarFavoritos(usuarioId);
      debugPrint('RECOMENDACAO: favoritos=${favoritos.length}');
      if (favoritos.isEmpty) return [];

      // 2. Obras candidatas (não favoritadas)
      final todasObras = await _obrasRepo.listarTodas();
      final idsJaFavoritados = favoritos.map((o) => o.id).toSet();
      final candidatas = todasObras
          .where((o) => !idsJaFavoritados.contains(o.id))
          .toList();

      if (candidatas.isEmpty) return [];

      // 3. Perfil de gêneros do usuário (nome → frequência)
      final perfilGeneros = await _generosRepo.perfilGenerosUsuario(usuarioId);

      // 4. Gêneros detalhados de cada favorito (para matching fino)
      final generosDosFavoritos = <String>{};
      for (final fav in favoritos) {
        final gs = await _generosRepo.listarPorObra(fav.id);
        for (final g in gs) {
          generosDosFavoritos.add(g.nome.toLowerCase());
        }
        // Inclui o campo genero simples também
        if (fav.genero != null) {
          generosDosFavoritos.add(fav.genero!.toLowerCase());
        }
      }

      // 5. Status preferidos (obras em andamento têm leve bônus)
      final statusFavoritos = <String>{};
      for (final fav in favoritos) {
        statusFavoritos.add(fav.status);
      }

      // 6. Pontua cada candidata
      final scored = <ObraRecomendada>[];

      for (final obra in candidatas) {
        double score = 0.0;

        // Gêneros da obra candidata
        final generosObra = await _generosRepo.listarPorObra(obra.id);
        final nomesGenerosObra = generosObra
            .map((g) => g.nome.toLowerCase())
            .toSet();

        // Adiciona genero simples do campo texto
        if (obra.genero != null) {
          nomesGenerosObra.add(obra.genero!.toLowerCase());
        }

        // Interseção com perfil do usuário (peso principal)
        int coincidencias = 0;
        for (final nomeGenero in nomesGenerosObra) {
          if (generosDosFavoritos.contains(nomeGenero)) {
            coincidencias++;
          }
          // Peso extra por frequência no perfil
          final freq = perfilGeneros[nomeGenero] ?? 0;
          score += freq * 0.1;
        }

        score += coincidencias * 0.3;

        // Bônus por status igual ao dos favoritos
        if (statusFavoritos.contains(obra.status)) {
          score += 0.05;
        }

        // Bônus leve para obras em destaque
        if (obra.destaque) {
          score += 0.05;
        }

        if (score > 0) {
          scored.add(ObraRecomendada(obra: obra, score: score));
        }
      }

      // 7. Se nenhuma teve score > 0, retorna todas as candidatas com score baixo
      if (scored.isEmpty) {
        debugPrint('RECOMENDACAO: sem matches de gênero, retornando candidatas por destaque');
        for (final obra in candidatas) {
          double s = obra.destaque ? 0.3 : 0.1;
          scored.add(ObraRecomendada(obra: obra, score: s));
        }
      }

      // 8. Normaliza scores para 0.0-1.0
      final maxScore = scored.map((r) => r.score).reduce((a, b) => a > b ? a : b);
      final normalizados = scored
          .map((r) => ObraRecomendada(
                obra: r.obra,
                score: maxScore > 0 ? r.score / maxScore : 0.0,
              ))
          .toList();

      // 9. Ordena e retorna topN
      normalizados.sort((a, b) => b.score.compareTo(a.score));
      final resultado = normalizados.take(topN).toList();

      debugPrint('RECOMENDACAO: ${resultado.length} obras recomendadas (local)');
      for (final r in resultado) {
        debugPrint('  - ${r.obra.titulo}: ${(r.score * 100).round()}%');
      }

      return resultado;
    } catch (e, st) {
      debugPrint('RECOMENDACAO ERRO: $e\n$st');
      return [];
    }
  }
}

class ObraRecomendada {
  final Obra obra;

  /// Valor entre 0.0 e 1.0. Quanto maior, mais compatível com o perfil.
  final double score;

  const ObraRecomendada({required this.obra, required this.score});
}