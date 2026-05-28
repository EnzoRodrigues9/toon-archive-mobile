import 'dart:convert';
import 'dart:math';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../models/obra.dart';
import '../repositories/favoritos_repository.dart';
import '../repositories/obras_repository.dart';
import '../repositories/generos_repository.dart';
import '../core/helpers/app.config.dart';

/// Recomendação com IA real (Hugging Face Inference API) + fallback local.
///
/// MODELO: sentence-transformers/all-MiniLM-L6-v2
///   - Transforma textos em vetores de 384 dimensões (embeddings)
///   - Similaridade de cosseno mede o quão parecidos dois textos são
///
/// FLUXO:
///   1. Monta texto de perfil do usuário (favoritos + gêneros)
///   2. Monta texto de cada obra candidata (título + gêneros)
///   3. Envia tudo ao HF em uma única chamada (feature-extraction)
///   4. Calcula similaridade de cosseno: perfil × cada candidata
///   5. Ordena por score e retorna topN
///   6. OFFLINE ou FALHA → fallback ao algoritmo local por gênero
///   7. COLD START (sem favoritos) → retorna destaques
class RecomendacaoService {
  RecomendacaoService._();
  static final RecomendacaoService instance = RecomendacaoService._();

  final _favoritosRepo = FavoritosRepository.instance;
  final _obrasRepo     = ObrasRepository.instance;
  final _generosRepo   = GenerosRepository.instance;

  final _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 30),
  ));

  // Hugging Face Inference API — sentence-transformers
  static const _hfUrl =
      'https://api-inference.huggingface.co/models/'
      'sentence-transformers/all-MiniLM-L6-v2';

  // ── Ponto de entrada ──────────────────────────────────────

  Future<List<ObraRecomendada>> recomendar({
    required String usuarioId,
    int topN = 5,
  }) async {
    try {
      final favoritos  = await _favoritosRepo.listarFavoritos(usuarioId);
      final todasObras = await _obrasRepo.listarTodas();

      // COLD START: sem favoritos → destaques
      if (favoritos.isEmpty) {
        return _fallbackDestaques(todasObras, topN: topN);
      }

      // Obras que o usuário ainda não interagiu
      final idsInteragidos = favoritos.map((o) => o.id).toSet();
      final candidatas = todasObras
          .where((o) => !idsInteragidos.contains(o.id))
          .toList();

      if (candidatas.isEmpty) return [];

      // Perfil de gêneros (usado tanto pela IA quanto pelo fallback)
      final perfilGeneros = await _buildPerfilGeneros(favoritos);

      // Tenta HF Inference API se online e chave configurada
      if (await _online() && AppConfig.huggingFaceApiKey.isNotEmpty) {
        try {
          final resultado = await _recomendarComEmbeddings(
            favoritos:     favoritos,
            candidatas:    candidatas,
            perfilGeneros: perfilGeneros,
            topN:          topN,
          );
          if (resultado.isNotEmpty) return resultado;
        } catch (e) {
          debugPrint('HF EMBEDDINGS ERRO: $e — usando fallback local');
        }
      }

      // Fallback local por score de gênero
      return _recomendarLocal(
        candidatas:    candidatas,
        favoritos:     favoritos,
        perfilGeneros: perfilGeneros,
        topN:          topN,
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
    // ── 1. Monta texto do perfil do usuário ──────────────────
    // Combina títulos favoritados + gêneros mais frequentes
    final titulosFav = favoritos.map((o) => o.titulo).join(', ');
    final topGeneros = (perfilGeneros.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value)))
        .take(6)
        .map((e) => e.key)
        .join(', ');

    final textoPerfil =
        'Manga favoritos: $titulosFav. Generos preferidos: $topGeneros';

    // ── 2. Monta texto de cada candidata ─────────────────────
    // Máx 30 candidatas para não estourar o limite da API gratuita
    final candidatasLimitadas = candidatas.take(30).toList();
    final textosCandidatas = candidatasLimitadas.map((o) {
      final genero = o.genero ?? '';
      return 'Titulo: ${o.titulo}. Genero: $genero';
    }).toList();

    // ── 3. Chama a API em lote: perfil + todas as candidatas ─
    // O endpoint feature-extraction aceita uma lista de sentenças
    // e retorna um embedding por sentença
    final inputs = [textoPerfil, ...textosCandidatas];

    final response = await _dio.post(
      _hfUrl,
      data: jsonEncode({'inputs': inputs, 'options': {'wait_for_model': true}}),
      options: Options(headers: {
        'Authorization': 'Bearer ${AppConfig.huggingFaceApiKey}',
        'Content-Type': 'application/json',
      }),
    );

    // Resposta: List<List<double>> — um vetor por sentença
    final List<dynamic> rawEmbeddings = response.data as List<dynamic>;
    if (rawEmbeddings.length != inputs.length) return [];

    final List<List<double>> embeddings = rawEmbeddings
        .map((e) => (e as List<dynamic>).map((v) => (v as num).toDouble()).toList())
        .toList();

    // ── 4. Separa embedding do perfil dos embeddings das obras ─
    final embPerfil     = embeddings[0];
    final embCandidatas = embeddings.sublist(1);

    // ── 5. Calcula similaridade de cosseno ────────────────────
    final scored = <ObraRecomendada>[];

    for (int i = 0; i < candidatasLimitadas.length; i++) {
      final obra        = candidatasLimitadas[i];
      final similarity  = _cosineSimilarity(embPerfil, embCandidatas[i]);

      // Bônus leve para obras em destaque (não muda o ranking, só empurra
      // empates para cima)
      final scoreComBonus = similarity + (obra.destaque ? 0.03 : 0.0);

      // Monta motivo baseado no gênero mais próximo dos favoritos
      final motivo = _motivoPorGenero(obra, favoritos);

      scored.add(ObraRecomendada(
        obra:   obra,
        score:  scoreComBonus.clamp(0.0, 1.0),
        motivo: motivo,
      ));
    }

    // ── 6. Ordena e retorna topN ──────────────────────────────
    scored.sort((a, b) => b.score.compareTo(a.score));
    final resultado = scored.take(topN).toList();

    debugPrint('HF recomendou ${resultado.length} obras');
    for (final r in resultado) {
      debugPrint(
          '  ${r.obra.titulo}: ${(r.score * 100).toStringAsFixed(1)}% — ${r.motivo}');
    }

    return resultado;
  }

  // ── Similaridade de Cosseno ───────────────────────────────
  //
  // cos(θ) = (A · B) / (|A| × |B|)
  // Resultado entre -1 e 1; quanto mais próximo de 1, mais similar.

  double _cosineSimilarity(List<double> a, List<double> b) {
    double dot    = 0.0;
    double normA  = 0.0;
    double normB  = 0.0;

    for (int i = 0; i < a.length; i++) {
      dot   += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }

    final denom = sqrt(normA) * sqrt(normB);
    return denom == 0 ? 0.0 : dot / denom;
  }

  // ── Fallback local (offline / falha de rede) ──────────────

  List<ObraRecomendada> _recomendarLocal({
    required List<Obra> candidatas,
    required List<Obra> favoritos,
    required Map<String, double> perfilGeneros,
    required int topN,
  }) {
    final statusFavoritos = favoritos.map((o) => o.status).toSet();
    final scored = <ObraRecomendada>[];

    for (final obra in candidatas) {
      double score = 0.0;
      final generos = <String>{
        if (obra.genero != null && obra.genero!.isNotEmpty)
          obra.genero!.toLowerCase(),
      };

      for (final g in generos) {
        score += perfilGeneros[g] ?? 0;
      }
      if (statusFavoritos.contains(obra.status)) score += 0.5;
      if (obra.destaque) score += 1.0;

      if (score > 0) {
        scored.add(ObraRecomendada(
          obra:   obra,
          score:  score,
          motivo: _motivoPorGenero(obra, favoritos),
        ));
      }
    }

    if (scored.isEmpty) return _fallbackDestaques(candidatas, topN: topN);

    final max = scored.map((r) => r.score).reduce((a, b) => a > b ? a : b);
    scored.sort((a, b) => b.score.compareTo(a.score));

    return scored
        .take(topN)
        .map((r) => ObraRecomendada(
              obra:   r.obra,
              score:  max > 0 ? (r.score / max).clamp(0.0, 1.0) : 0.0,
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
              obra:   o,
              score:  o.destaque ? 0.85 : 0.50,
              motivo: o.destaque ? 'Em destaque' : 'Popular no catálogo',
            ))
        .toList();
  }

  // ── Helpers ───────────────────────────────────────────────

  /// Gera motivo legível baseado no gênero que a obra tem em comum
  /// com os favoritos do usuário.
  String _motivoPorGenero(Obra obra, List<Obra> favoritos) {
    if (obra.genero == null || obra.genero!.isEmpty) {
      return 'Pode te interessar';
    }
    final genObra = obra.genero!.toLowerCase();
    for (final fav in favoritos) {
      if (fav.genero?.toLowerCase() == genObra) {
        final nome = fav.titulo.length > 16
            ? '${fav.titulo.substring(0, 14)}…'
            : fav.titulo;
        return 'Similar a $nome';
      }
    }
    return 'Gênero: ${obra.genero}';
  }

  Future<Map<String, double>> _buildPerfilGeneros(List<Obra> favoritos) async {
    final Map<String, double> perfil = {};
    for (final fav in favoritos) {
      final gs = await _generosRepo.listarPorObra(fav.id);
      for (final g in gs) {
        final nome = g.nome.toLowerCase();
        perfil[nome] = (perfil[nome] ?? 0) + 3.0;
      }
      if (fav.genero != null && fav.genero!.isNotEmpty) {
        final nome = fav.genero!.toLowerCase();
        perfil[nome] = (perfil[nome] ?? 0) + 3.0;
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

  /// Score de similaridade de cosseno (0.0 – 1.0).
  final double score;

  /// Texto curto exibido no card de recomendação.
  final String motivo;

  const ObraRecomendada({
    required this.obra,
    required this.score,
    this.motivo = '',
  });
}