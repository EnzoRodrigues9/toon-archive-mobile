import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sqflite/sqflite.dart';
import '../core/database/database_helper.dart';
import '../models/pagina.dart';

class PaginasRepository {
  PaginasRepository._();

  static final PaginasRepository instance =
      PaginasRepository._();

  final _supabase = Supabase.instance.client;

  // =========================================================
  // LISTAR PÁGINAS POR CAPÍTULO
  // =========================================================
  Future<List<Pagina>> listarPorCapitulo(
    String capituloId,
  ) async {
    final db = await DatabaseHelper.instance.database;

    // 1. tenta SQLite primeiro (offline-first)
    final local = await db.query(
      'paginas',
      where: 'capitulo_id = ?',
      whereArgs: [capituloId],
      orderBy: 'numero ASC',
    );

    // Se encontrou localmente, retorna
    if (local.isNotEmpty) {
      return local
          .map((map) => Pagina.fromMap(map))
          .toList();
    }

    // 2. busca no Supabase
    final response = await _supabase
        .from('paginas')
        .select()
        .eq('capitulo_id', capituloId)
        .order('numero');

    final paginas = (response as List)
        .map((map) => Pagina.fromMap(map))
        .toList();

    // 3. salva cache local
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
      {
        'imagem_local': caminhoLocal,
      },
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

    if (resultado.isEmpty) {
      return null;
    }

    return Pagina.fromMap(resultado.first);
  }

  // =========================================================
  // REMOVER CACHE DE UM CAPÍTULO
  // =========================================================
  Future<void> removerPorCapitulo(
    String capituloId,
  ) async {
    final db = await DatabaseHelper.instance.database;

    await db.delete(
      'paginas',
      where: 'capitulo_id = ?',
      whereArgs: [capituloId],
    );
  }
}