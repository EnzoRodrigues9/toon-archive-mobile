import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:toonarchive/app/modules/paginas/pagina.dart';

class DownloadService {
  DownloadService._();
  static final instance = DownloadService._();

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 60),
    ),
  );

  // ── Pasta do capítulo ──────────────────────────────────────

  Future<String> _getPastaCapitulo({
    required String obraId,
    required String capituloId,
  }) async {
    final dir = await getApplicationDocumentsDirectory();
    final pasta = Directory(p.join(dir.path, 'downloads', obraId, capituloId));
    if (!await pasta.exists()) await pasta.create(recursive: true);
    return pasta.path;
  }

  // ── Download de uma imagem ─────────────────────────────────

  /// Baixa a imagem e retorna o caminho local.
  /// Usa cache: se o arquivo já existir, retorna sem re-baixar.
  Future<String> baixarImagem({
    required String obraId,
    required String capituloId,
    required Pagina pagina,
    void Function(int baixado, int total)? onProgresso,
  }) async {
    final pasta = await _getPastaCapitulo(
        obraId: obraId, capituloId: capituloId);

    // Extrai extensão com segurança, evitando parâmetros de query na URL
    final urlSemQuery = pagina.imagemUrl.split('?').first;
    final extensao = urlSemQuery.contains('.')
        ? urlSemQuery.split('.').last
        : 'jpg';

    final caminhoArquivo =
        p.join(pasta, 'pagina_${pagina.numero}.$extensao');

    // Cache local: não re-baixa se o arquivo já existir
    if (await File(caminhoArquivo).exists()) return caminhoArquivo;

    await _dio.download(
      pagina.imagemUrl,
      caminhoArquivo,
      onReceiveProgress: onProgresso,
      options: Options(
        // Segue redirecionamentos automaticamente
        followRedirects: true,
        validateStatus: (status) => status != null && status < 500,
      ),
    );

    return caminhoArquivo;
  }

  // ── Download de todas as páginas de um capítulo ────────────

  /// Baixa todas as páginas em paralelo (máx. 3 simultâneas).
  /// Retorna mapa de paginaId → caminhoLocal.
  /// [onProgresso] recebe (paginasBaixadas, totalPaginas).
  Future<Map<String, String>> baixarCapitulo({
    required String obraId,
    required String capituloId,
    required List<Pagina> paginas,
    void Function(int baixado, int total)? onProgresso,
  }) async {
    final resultado = <String, String>{};
    int baixadas = 0;
    final total = paginas.length;

    // Processa em lotes de 3 para não sobrecarregar a rede
    const lote = 3;
    for (int i = 0; i < paginas.length; i += lote) {
      final fim = (i + lote).clamp(0, paginas.length);
      final grupo = paginas.sublist(i, fim);

      await Future.wait(
        grupo.map((pagina) async {
          final caminho = await baixarImagem(
            obraId: obraId,
            capituloId: capituloId,
            pagina: pagina,
          );
          resultado[pagina.id] = caminho;
          baixadas++;
          onProgresso?.call(baixadas, total);
        }),
      );
    }

    return resultado;
  }

  // ── Remover arquivos físicos de um capítulo ────────────────

  Future<void> removerArquivosCapitulo({
    required String obraId,
    required String capituloId,
  }) async {
    final dir = await getApplicationDocumentsDirectory();
    final pasta = Directory(
        p.join(dir.path, 'downloads', obraId, capituloId));
    if (await pasta.exists()) await pasta.delete(recursive: true);
  }
}