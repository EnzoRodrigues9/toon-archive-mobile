import 'dart:convert';
import 'dart:math';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:toonarchive/app/modules/obras/obra.dart';
import 'package:toonarchive/app/modules/generos/genero.dart';
import 'package:toonarchive/app/modules/favoritos/favoritos_repository.dart';
import 'package:toonarchive/app/modules/obras/obras_repository.dart';
import 'package:toonarchive/app/modules/generos/generos_repository.dart';
import 'package:toonarchive/app/core/helpers/app.config.dart';

/// Recomendação com IA real (Hugging Face Inference API) + fallback local.
///
/// MODELO: paraphrase-multilingual-MiniLM-L12-v2
///
class RecomendacaoService {
  RecomendacaoService._();
  static final RecomendacaoService instance = RecomendacaoService._();

  final _favoritosRepo = FavoritosRepository.instance;
  final _obrasRepo = ObrasRepository.instance;
  final _generosRepo = GenerosRepository.instance;

  final _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 30),
  ));

  static const _hfUrl = 'https://router.huggingface.co/hf-inference/models/'
      'sentence-transformers/paraphrase-multilingual-MiniLM-L12-v2/pipeline/feature-extraction';

  static const _scoreMinimo = 0.30;

  // Gêneros que não carregam sinal semântico útil para embeddings.
  static const _generosIgnorados = {
    'mangá',
    'manhwa',
    'manhua',
    'livro',
    'webtoon',
    'shonen',
    'shounen',
    'seinen',
    'josei',
    'shoujo',
    'kodomomuke',
  };

  // Mesmo conjunto — não usar como motivo de recomendação.
  static const _generosIgnoradosMotivo = {
    'mangá',
    'manhwa',
    'manhua',
    'livro',
    'webtoon',
    'shonen',
    'shounen',
    'seinen',
    'josei',
    'shoujo',
    'kodomomuke',
  };

  static const _traducao = {
    'ação': 'action',
    'aventura': 'adventure',
    'fantasia': 'fantasy',
    'romance': 'romance',
    'terror': 'horror',
    'comédia': 'comedy',
    'ficção científica': 'sci-fi',
    'drama': 'drama',
    'mistério': 'mystery',
    'sobrenatural': 'supernatural',
    'psicológico': 'psychological',
    'suspense': 'thriller',
    'esporte': 'sports',
    'histórico': 'historical',
    'slice of life': 'slice of life',
    'escolar': 'school life',
  };

  String _traduzir(String genero) =>
      _traducao[genero.toLowerCase()] ?? genero.toLowerCase();

  // ── Ponto de entrada ──────────────────────────────────────

  Future<List<ObraRecomendada>> recomendar({
    required String usuarioId,
    int topN = 5,
  }) async {
    try {
      final favoritos = await _favoritosRepo.listarFavoritos(usuarioId);
      final todasObras = await _obrasRepo.listarTodas();

      if (favoritos.isEmpty) {
        return _fallbackDestaques(todasObras, topN: topN);
      }

      final idsInteragidos = favoritos.map((o) => o.id).toSet();
      final candidatas =
          todasObras.where((o) => !idsInteragidos.contains(o.id)).toList();

      if (candidatas.isEmpty) return [];

      final perfilGeneros = await _buildPerfilGeneros(favoritos);

      if (await _online() && AppConfig.huggingFaceApiKey.isNotEmpty) {
        try {
          final resultado = await _recomendarComEmbeddings(
            favoritos: favoritos,
            candidatas: candidatas,
            perfilGeneros: perfilGeneros,
            topN: topN,
          );
          if (resultado.isNotEmpty) return resultado;
        } catch (e) {
          debugPrint('HF EMBEDDINGS ERRO: $e — usando fallback local');
        }
      }

      return await _recomendarLocal(
        candidatas: candidatas,
        favoritos: favoritos,
        perfilGeneros: perfilGeneros,
        topN: topN,
      );
    } catch (e, st) {
      debugPrint('RECOMENDACAO ERRO: $e\n$st');
      return [];
    }
  }

  // ── Hugging Face Embeddings ───────────────────────────────

  Future<List<ObraRecomendada>> _recomendarComEmbeddings({
    required List<Obra> favoritos,
    required List<Obra> candidatas,
    required Map<String, double> perfilGeneros,
    required int topN,
  }) async {
    // ── Texto de perfil enriquecido ────────────────────────
    final bufferPerfil = StringBuffer();
    for (final fav in favoritos) {
      final generos = await _generosRepo.listarPorObra(fav.id);
      final generosNarrativos = generos
          .where((g) =>
              g.categoria == 'narrativo' &&
              !_generosIgnorados.contains(g.nome.toLowerCase()))
          .map((g) => _traduzir(g.nome))
          .join(', ');

      bufferPerfil.write('${fav.titulo}');
      if (fav.descricao != null && fav.descricao!.isNotEmpty) {
        bufferPerfil.write(': ${fav.descricao}');
      }
      if (generosNarrativos.isNotEmpty) {
        bufferPerfil.write(' [$generosNarrativos]');
      }
      bufferPerfil.write('. ');
    }

    final textoPerfil = 'Manga I enjoy: ${bufferPerfil.toString().trim()}';
    debugPrint('PERFIL TEXT: $textoPerfil');

    // ── Texto e gêneros de cada candidata ─────────────────
    // Carrega e armazena gêneros para usar no scoring (evita dupla busca).
    final candidatasLimitadas = candidatas.take(30).toList();
    final generosCandidatas = <String, List<Genero>>{};
    final textosCandidatas = <String>[];

    for (final o in candidatasLimitadas) {
      final generos = await _generosRepo.listarPorObra(o.id);
      generosCandidatas[o.id] = generos;

      final generosNarrativos = generos
          .where((g) =>
              g.categoria == 'narrativo' &&
              !_generosIgnorados.contains(g.nome.toLowerCase()))
          .map((g) => _traduzir(g.nome))
          .join(', ');

      final buf = StringBuffer('${o.titulo}');
      if (o.descricao != null && o.descricao!.isNotEmpty) {
        buf.write(': ${o.descricao}');
      }
      if (generosNarrativos.isNotEmpty) {
        buf.write(' [$generosNarrativos]');
      }
      textosCandidatas.add(buf.toString());
    }

    // ── Chamada à API ──────────────────────────────────────
    final inputs = [textoPerfil, ...textosCandidatas];

    final response = await _dio.post(
      _hfUrl,
      data: jsonEncode({
        'inputs': inputs,
        'options': {'wait_for_model': true},
      }),
      options: Options(headers: {
        'Authorization': 'Bearer ${AppConfig.huggingFaceApiKey}',
        'Content-Type': 'application/json',
      }),
    );

    final List<dynamic> rawEmbeddings = response.data as List<dynamic>;
    if (rawEmbeddings.length != inputs.length) return [];

    final List<List<double>> embeddings = rawEmbeddings
        .map((e) =>
            (e as List<dynamic>).map((v) => (v as num).toDouble()).toList())
        .toList();

    final embPerfil = embeddings[0];
    final embCandidatas = embeddings.sublist(1);

    // ── Scoring com multiplicador de overlap ───────────────
    final scored = <ObraRecomendada>[];

    for (int i = 0; i < candidatasLimitadas.length; i++) {
      final obra = candidatasLimitadas[i];
      final generos = generosCandidatas[obra.id] ?? [];

      final similarity = _cosineSimilarity(embPerfil, embCandidatas[i]);
      final overlapFactor = _calcularOverlapFactor(generos, perfilGeneros);

      // Multiplicador de gênero é o filtro principal:
      //   - overlap 0.0 → ×0.30  (obras sem gênero em comum são fortemente penalizadas)
      //   - overlap 0.5 → ×0.825 (overlap parcial)
      //   - overlap 1.0 → ×1.10  (overlap total ganha leve bônus)
      // Isso significa que Ação nunca vai superar Romance para um usuário de Romance.
      final scoreFinal =
          similarity * overlapFactor + (obra.destaque ? 0.008 : 0.0);

      debugPrint(
          '  SCORE ${obra.titulo}: ${(scoreFinal * 100).toStringAsFixed(1)}%'
          ' (cos=${(similarity * 100).toStringAsFixed(1)}%'
          ' overlap_factor=${overlapFactor.toStringAsFixed(2)})');

      if (scoreFinal < _scoreMinimo) continue;

      final motivo = await _motivoPorGenero(obra, favoritos);
      scored.add(ObraRecomendada(
        obra: obra,
        score: scoreFinal.clamp(0.0, 1.0),
        motivo: motivo,
      ));
    }

    scored.sort((a, b) => b.score.compareTo(a.score));
    final resultado = scored.take(topN).toList();

    debugPrint('HF recomendou ${resultado.length} obras');
    for (final r in resultado) {
      debugPrint(
          '  ${r.obra.titulo}: ${(r.score * 100).toStringAsFixed(1)}% — ${r.motivo}');
    }

    // Se nada passou o threshold, retorna o top-N sem filtro para não
    // deixar a seção vazia. Caso real: catálogo muito pequeno.
    if (resultado.isEmpty) {
      scored.clear();
      for (int i = 0; i < candidatasLimitadas.length; i++) {
        final obra = candidatasLimitadas[i];
        final generos = generosCandidatas[obra.id] ?? [];
        final similarity = _cosineSimilarity(embPerfil, embCandidatas[i]);
        final overlapFactor = _calcularOverlapFactor(generos, perfilGeneros);
        final scoreF =
            similarity * overlapFactor + (obra.destaque ? 0.008 : 0.0);
        final motivo = await _motivoPorGenero(obra, favoritos);
        scored.add(ObraRecomendada(
            obra: obra, score: scoreF.clamp(0.0, 1.0), motivo: motivo));
      }
      scored.sort((a, b) => b.score.compareTo(a.score));
      debugPrint('HF: nenhuma obra passou threshold, top-$topN sem filtro');
      return scored.take(topN).toList();
    }

    return resultado;
  }

  // ── Multiplicador de overlap de gêneros (0.30 – 1.10) ────
  //
  // Recebe a lista de gêneros da candidata e o perfil de frequência
  // do usuário. Retorna um fator que é usado para multiplicar o score
  // de embedding, garantindo que afinidade de gênero domine a seleção.
  //
  // Exemplos para perfil {romance: 8, drama: 4, comédia: 4}:
  //   Kaguya (romance, comédia, drama) → overlap alto → fator ~1.10
  //   Naruto (ação, aventura, fantasia) → overlap 0   → fator 0.30
  //   Obra com romance + ação           → overlap médio → fator ~0.75
  double _calcularOverlapFactor(
    List<Genero> generosCandidata,
    Map<String, double> perfilGeneros,
  ) {
    if (perfilGeneros.isEmpty) return 1.0; // sem dados → não penaliza

    final nomesNarrativos = generosCandidata
        .where((g) =>
            g.categoria == 'narrativo' &&
            !_generosIgnorados.contains(g.nome.toLowerCase()))
        .map((g) => g.nome.toLowerCase())
        .toSet();

    if (nomesNarrativos.isEmpty) {
      // Candidata sem gêneros narrativos mapeados → penalidade moderada
      return 0.50;
    }

    // Soma dos pesos de perfil que coincidem com a candidata
    double scoreOverlap = 0.0;
    double totalPerfil = 0.0;

    for (final entry in perfilGeneros.entries) {
      totalPerfil += entry.value;
      if (nomesNarrativos.contains(entry.key)) {
        scoreOverlap += entry.value;
      }
    }

    if (totalPerfil == 0) return 1.0;

    // overlapRatio: 0.0 = nenhum gênero em comum; 1.0 = todos em comum
    final overlapRatio = (scoreOverlap / totalPerfil).clamp(0.0, 1.0);

    // Mapeamento contínuo:
    //   overlapRatio = 0.0 → fator = 0.30 (fortíssima penalidade)
    //   overlapRatio = 0.5 → fator ≈ 0.70
    //   overlapRatio = 1.0 → fator = 1.10 (leve bônus)
    return (0.30 + overlapRatio * 0.80).clamp(0.30, 1.10);
  }

  // ── Similaridade de Cosseno ───────────────────────────────

  double _cosineSimilarity(List<double> a, List<double> b) {
    double dot = 0.0, normA = 0.0, normB = 0.0;
    for (int i = 0; i < a.length; i++) {
      dot += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }
    final denom = sqrt(normA) * sqrt(normB);
    return denom == 0 ? 0.0 : dot / denom;
  }

  // ── Fallback local (offline / falha de rede) ──────────────

  Future<List<ObraRecomendada>> _recomendarLocal({
    required List<Obra> candidatas,
    required List<Obra> favoritos,
    required Map<String, double> perfilGeneros,
    required int topN,
  }) async {
    final statusFavoritos = favoritos.map((o) => o.status).toSet();
    final scored = <ObraRecomendada>[];

    for (final obra in candidatas) {
      final generos = await _generosRepo.listarPorObra(obra.id);

      // Score bruto por frequência de gênero narrativo no perfil
      double scoreBase = 0.0;
      for (final g in generos) {
        if (g.categoria == 'narrativo' &&
            !_generosIgnorados.contains(g.nome.toLowerCase())) {
          scoreBase += perfilGeneros[g.nome.toLowerCase()] ?? 0;
        }
      }

      // Fallback para campo simples se não há narrativos mapeados
      if (scoreBase == 0 && obra.genero != null && obra.genero!.isNotEmpty) {
        scoreBase += perfilGeneros[obra.genero!.toLowerCase()] ?? 0;
      }

      if (statusFavoritos.contains(obra.status)) scoreBase += 0.5;
      if (obra.destaque) scoreBase += 0.5; // bônus menor que no original

      // Aplica o mesmo multiplicador de overlap para consistência
      final overlapFactor = _calcularOverlapFactor(generos, perfilGeneros);
      final scoreFinal = scoreBase * overlapFactor;

      if (scoreFinal > 0) {
        final motivo = await _motivoPorGenero(obra, favoritos);
        scored.add(
            ObraRecomendada(obra: obra, score: scoreFinal, motivo: motivo));
      }
    }

    if (scored.isEmpty) return _fallbackDestaques(candidatas, topN: topN);

    final maxScore = scored.map((r) => r.score).reduce((a, b) => a > b ? a : b);
    scored.sort((a, b) => b.score.compareTo(a.score));

    return scored
        .take(topN)
        .map((r) => ObraRecomendada(
              obra: r.obra,
              score: maxScore > 0 ? (r.score / maxScore).clamp(0.0, 1.0) : 0.0,
              motivo: r.motivo,
            ))
        .toList();
  }

  // ── Cold start ────────────────────────────────────────────

  List<ObraRecomendada> _fallbackDestaques(
    List<Obra> obras, {
    required int topN,
  }) {
    final destaques = obras.where((o) => o.destaque).take(topN).toList();
    final lista = destaques.isNotEmpty ? destaques : obras.take(topN).toList();
    return lista
        .map((o) => ObraRecomendada(
              obra: o,
              score: o.destaque ? 0.85 : 0.50,
              motivo: o.destaque ? 'Em destaque' : 'Popular no catálogo',
            ))
        .toList();
  }

  // ── Helpers ───────────────────────────────────────────────

  Future<String> _motivoPorGenero(Obra obra, List<Obra> favoritos) async {
    final generosObra = await _generosRepo.listarPorObra(obra.id);
    final nomesGenerosObra = generosObra
        .map((g) => g.nome.toLowerCase())
        .where((n) => !_generosIgnoradosMotivo.contains(n))
        .toSet();

    if (nomesGenerosObra.isEmpty) return 'Pode te interessar';

    for (final fav in favoritos) {
      final generosFav = await _generosRepo.listarPorObra(fav.id);
      final nomesGenerosFav = generosFav
          .map((g) => g.nome.toLowerCase())
          .where((n) => !_generosIgnoradosMotivo.contains(n))
          .toSet();

      final emComum = nomesGenerosObra.intersection(nomesGenerosFav).toList();
      if (emComum.isNotEmpty) {
        final narrativos = generosFav
            .where((g) =>
                g.categoria == 'narrativo' &&
                emComum.contains(g.nome.toLowerCase()))
            .map((g) => g.nome)
            .toList();
        if (narrativos.isNotEmpty) return narrativos.first;
        final genero = emComum.first;
        return genero[0].toUpperCase() + genero.substring(1);
      }
    }

    final narrativo = generosObra
        .where((g) => g.categoria == 'narrativo')
        .map((g) => g.nome)
        .firstOrNull;

    return narrativo ?? 'Pode te interessar';
  }

  Future<Map<String, double>> _buildPerfilGeneros(List<Obra> favoritos) async {
    final Map<String, double> perfil = {};
    for (final fav in favoritos) {
      final gs = await _generosRepo.listarPorObra(fav.id);
      for (final g in gs) {
        if (g.categoria != 'narrativo') continue;
        final nome = g.nome.toLowerCase();
        if (_generosIgnorados.contains(nome)) continue;
        perfil[nome] = (perfil[nome] ?? 0) + 4.0;
      }
    }
    return perfil;
  }

  Future<bool> _online() async {
    final r = await Connectivity().checkConnectivity();
    return r.any((c) => c != ConnectivityResult.none);
  }
}

// ── Model ─────────────────────────────────────────────────

class ObraRecomendada {
  final Obra obra;

  /// Score final (embedding × overlap_factor + destaque_bonus).
  final double score;

  /// Texto curto exibido no card de recomendação.
  final String motivo;

  const ObraRecomendada({
    required this.obra,
    required this.score,
    this.motivo = '',
  });
}
