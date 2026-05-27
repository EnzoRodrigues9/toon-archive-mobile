import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:uuid/uuid.dart';
import '../core/database/database_helper.dart';
import '../core/database/supabase_client.dart';
import '../core/sync/sync_service.dart';
import '../models/obra.dart';

/// Substitui o FavoritosService (SharedPreferences) pelo banco de dados.
/// Escreve sempre no SQLite primeiro; enfileira no sync_log se offline.
class FavoritosRepository {
  static final FavoritosRepository instance = FavoritosRepository._();
  FavoritosRepository._();

  final _db     = DatabaseHelper.instance;
  final _client = SupabaseClientHelper.client;
  final _uuid   = const Uuid();

  // ── Leitura ────────────────────────────────────────────────

  Future<List<Obra>> listarFavoritos(String usuarioId) async {
    // Sempre lê do SQLite para garantir funcionar offline
    final rows = await _db.rawQuery('''
      SELECT o.* FROM obras o
      INNER JOIN favoritos f ON f.obra_id = o.id
      WHERE f.usuario_id = ?
      ORDER BY f.criado_em DESC
    ''', [usuarioId]);
    return rows.map(Obra.fromMap).toList();
  }

  Future<bool> isFavorito(String usuarioId, String obraId) async {
    final rows = await _db.query('favoritos',
        where: 'usuario_id = ? AND obra_id = ?',
        whereArgs: [usuarioId, obraId]);
    return rows.isNotEmpty;
  }

  // ── Escrita ────────────────────────────────────────────────

  Future<void> adicionar(String usuarioId, String obraId) async {
    final id  = _uuid.v4();
    final now = DateTime.now().toIso8601String();
    final data = {
      'id':         id,
      'usuario_id': usuarioId,
      'obra_id':    obraId,
      'criado_em':  now,
    };

    // 1. Salva local
    await _db.insert('favoritos', data);

    // 2. Tenta Supabase direto se online, senão enfileira
    if (await _online()) {
      try {
        await _client.from('favoritos').upsert(data);
        return;
      } catch (_) {}
    }
    await SyncService.instance.enfileirar(
      usuarioId:  usuarioId,
      tabela:     'favoritos',
      operacao:   'INSERT',
      registroId: id,
      payload:    data,
    );
  }

  Future<void> remover(String usuarioId, String obraId) async {
    // Busca o id local antes de deletar
    final rows = await _db.query('favoritos',
        where: 'usuario_id = ? AND obra_id = ?',
        whereArgs: [usuarioId, obraId]);
    if (rows.isEmpty) return;

    final registroId = rows.first['id'] as String;

    // 1. Remove local
    await _db.delete('favoritos',
        'usuario_id = ? AND obra_id = ?', [usuarioId, obraId]);

    // 2. Tenta Supabase direto se online, senão enfileira
    if (await _online()) {
      try {
        await _client.from('favoritos').delete().eq('id', registroId);
        return;
      } catch (_) {}
    }
    await SyncService.instance.enfileirar(
      usuarioId:  usuarioId,
      tabela:     'favoritos',
      operacao:   'DELETE',
      registroId: registroId,
    );
  }

  Future<void> toggle(String usuarioId, String obraId) async {
    if (await isFavorito(usuarioId, obraId)) {
      await remover(usuarioId, obraId);
    } else {
      await adicionar(usuarioId, obraId);
    }
  }

  // ── Sync: puxa favoritos do Supabase e atualiza cache local ─

  Future<void> sincronizarDoSupabase(String usuarioId) async {
    if (!await _online()) return;
    try {
      final rows = await _client
          .from('favoritos')
          .select()
          .eq('usuario_id', usuarioId);

      // Substitui cache local
      await _db.delete('favoritos', 'usuario_id = ?', [usuarioId]);
      for (final row in rows) {
        await _db.insert('favoritos', {
          'id':         row['id'],
          'usuario_id': row['usuario_id'],
          'obra_id':    row['obra_id'],
          'criado_em':  row['criado_em'],
        });
      }
    } catch (_) {}
  }

  Future<bool> _online() async {
    final r = await Connectivity().checkConnectivity();
    return r.any((r) => r != ConnectivityResult.none);
  }
}