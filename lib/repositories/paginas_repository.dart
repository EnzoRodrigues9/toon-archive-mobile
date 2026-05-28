import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sqflite/sqflite.dart';
import '../core/database/database_helper.dart';
import '../models/pagina.dart';

class PaginasRepository {
  PaginasRepository._();

  static final PaginasRepository instance = PaginasRepository._();

  final _supabase = Supabase.instance.client;

  // =========================================================
  // LISTAR PÁGINAS — usado pelo DownloadService
  // Tenta cache local primeiro; se não tiver, busca no Supabase
  // e salva o cache (sem imagem_local = ainda não é download real).
  // =========================================================
  Future<List<Pagina>> listarPorCapitulo(String capituloId) async {
    final db = await DatabaseHelper.instance.database;

    final local = await db.query(
      'paginas',
      where: 'capitulo_id = ?',
      whereArgs: [capituloId],
      orderBy: 'numero ASC',
    );

    if (local.isNotEmpty) {
      return local.map((map) => Pagina.fromMap(map)).toList();
    }

    final response = await _supabase
        .from('paginas')
        .select()
        .eq('capitulo_id', capituloId)
        .order('numero');

    final paginas = (response as List).map((map) => Pagina.fromMap(map)).toList();

    for (final pagina in paginas) {
      await db.insert(
        'paginas',
        pagina.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    return paginas;
  }

  // =========================================================
  // LISTAR PÁGINAS PARA LEITURA ONLINE
  // Busca sempre do Supabase quando online — sem cache automático.
  // Isso evita que páginas visitadas online apareçam como "baixadas".
  // =========================================================
  Future<List<Pagina>> listarParaLeituraOnline(String capituloId) async {
    final response = await _supabase
        .from('paginas')
        .select()
        .eq('capitulo_id', capituloId)
        .order('numero');

    return (response as List).map((map) => Pagina.fromMap(map)).toList();
  }

  // =========================================================
  // LISTAR PÁGINAS BAIXADAS (só as que têm imagem_local válida)
  // Usado na leitura offline — garante que só exibe arquivos reais.
  // =========================================================
  Future<List<Pagina>> listarPaginasBaixadas(String capituloId) async {
    final db = await DatabaseHelper.instance.database;

    final rows = await db.query(
      'paginas',
      where: "capitulo_id = ? AND imagem_local IS NOT NULL AND imagem_local != ''",
      whereArgs: [capituloId],
      orderBy: 'numero ASC',
    );

    return rows.map((map) => Pagina.fromMap(map)).toList();
  }

  // =========================================================
  // SALVAR LOCAL
  // =========================================================
  Future<void> salvarLocal(Pagina pagina) async {
    final db = await DatabaseHelper.instance.database;

    await db.insert(
      'paginas',
      pagina.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // =========================================================
  // ATUALIZAR IMAGEM LOCAL
  // =========================================================
  Future<void> atualizarImagemLocal({
    required String paginaId,
    required String caminhoLocal,
  }) async {
    final db = await DatabaseHelper.instance.database;

    await db.update(
      'paginas',
      {'imagem_local': caminhoLocal},
      where: 'id = ?',
      whereArgs: [paginaId],
    );
  }

  // =========================================================
  // BUSCAR PÁGINA POR ID
  // =========================================================
  Future<Pagina?> buscarPorId(String id) async {
    final db = await DatabaseHelper.instance.database;

    final resultado = await db.query(
      'paginas',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (resultado.isEmpty) return null;
    return Pagina.fromMap(resultado.first);
  }

  // =========================================================
  // REMOVER CACHE DE UM CAPÍTULO
  // =========================================================
  Future<void> removerPorCapitulo(String capituloId) async {
    final db = await DatabaseHelper.instance.database;

    await db.delete(
      'paginas',
      where: 'capitulo_id = ?',
      whereArgs: [capituloId],
    );
  }
}