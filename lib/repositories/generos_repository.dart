import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../core/database/database_helper.dart';
import '../core/database/supabase_client.dart';
import '../models/genero.dart';

class GenerosRepository {
  static final GenerosRepository instance = GenerosRepository._();
  GenerosRepository._();

  final _db     = DatabaseHelper.instance;
  final _client = SupabaseClientHelper.client;
  final _uuid   = const Uuid();

  // ── Todos os gêneros (com cache) ──────────────────────────

  Future<List<Genero>> listarTodos() async {
    if (await _online()) {
      try {
        final rows = await _client.from('generos').select().order('categoria').order('nome');
        final generos = rows.map((r) => Genero.fromSupabase(r)).toList();
        await _cachear(generos);
        return generos;
      } catch (_) {}
    }
    final rows = await _db.query('generos', orderBy: 'categoria, nome');
    return rows.map(Genero.fromMap).toList();
  }

  Future<List<Genero>> listarPorCategoria(String categoria) async {
    final todos = await listarTodos();
    return todos.where((g) => g.categoria == categoria).toList();
  }

  // ── Gêneros de uma obra ───────────────────────────────────

  Future<List<Genero>> listarPorObra(String obraId) async {
    if (await _online()) {
      try {
        final rows = await _client
            .from('obra_generos')
            .select('generos(*)')
            .eq('obra_id', obraId);
        return rows
            .map((r) => Genero.fromSupabase(r['generos'] as Map<String, dynamic>))
            .toList();
      } catch (_) {}
    }
    final rows = await _db.rawQuery('''
      SELECT g.* FROM generos g
      INNER JOIN obra_generos og ON og.genero_id = g.id
      WHERE og.obra_id = ?
      ORDER BY g.categoria, g.nome
    ''', [obraId]);
    return rows.map(Genero.fromMap).toList();
  }

  // ── Obras favoritadas → gêneros para recomendação ─────────

  /// Retorna gêneros mais frequentes nas obras favoritadas pelo usuário.
  /// Útil para alimentar a IA de recomendação.
  Future<Map<String, int>> perfilGenerosUsuario(String usuarioId) async {
    final rows = await _db.rawQuery('''
      SELECT g.nome, g.categoria, COUNT(*) as freq
      FROM generos g
      INNER JOIN obra_generos og ON og.genero_id = g.id
      INNER JOIN favoritos f ON f.obra_id = og.obra_id
      WHERE f.usuario_id = ?
      GROUP BY g.id
      ORDER BY freq DESC
    ''', [usuarioId]);

    return {for (final r in rows) r['nome'] as String: r['freq'] as int};
  }

  // ── Vincular/desvincular gêneros a uma obra ───────────────

  Future<void> setGenerosObra(String obraId, List<String> generoIds) async {
    final db = await _db.database;
    await db.delete('obra_generos', where: 'obra_id = ?', whereArgs: [obraId]);
    for (final gId in generoIds) {
      await db.insert(
        'obra_generos',
        {'obra_id': obraId, 'genero_id': gId},
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
    if (await _online()) {
      try {
        await _client.from('obra_generos').delete().eq('obra_id', obraId);
        if (generoIds.isNotEmpty) {
          await _client.from('obra_generos').insert(
            generoIds.map((gId) => {'obra_id': obraId, 'genero_id': gId}).toList(),
          );
        }
      } catch (_) {}
    }
  }

  // ── Cache ─────────────────────────────────────────────────

  Future<void> _cachear(List<Genero> generos) async {
    final db = await _db.database;
    for (final g in generos) {
      await db.insert('generos', g.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  Future<bool> _online() async {
    final r = await Connectivity().checkConnectivity();
    return r != ConnectivityResult.none;
  }
}