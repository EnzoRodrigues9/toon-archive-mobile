import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:uuid/uuid.dart';
import '../core/database/database_helper.dart';
import '../core/database/supabase_client.dart';
import '../core/sync/sync_service.dart';
import '../models/download.dart';

class DownloadsRepository {
  static final DownloadsRepository instance = DownloadsRepository._();
  DownloadsRepository._();

  final _db     = DatabaseHelper.instance;
  final _client = SupabaseClientHelper.client;
  final _uuid   = const Uuid();

  // ── Leitura ────────────────────────────────────────────────

  Future<List<Download>> listarPorUsuario(String usuarioId) async {
    final rows = await _db.query(
      'downloads',
      where:    'usuario_id = ?',
      whereArgs: [usuarioId],
      orderBy:  'criado_em DESC',
    );
    return rows.map(Download.fromMap).toList();
  }

  Future<Download?> buscar(String usuarioId, String capituloId) async {
    final rows = await _db.query(
      'downloads',
      where:    'usuario_id = ? AND capitulo_id = ?',
      whereArgs: [usuarioId, capituloId],
    );
    return rows.isNotEmpty ? Download.fromMap(rows.first) : null;
  }

  Future<bool> jaDownloaded(String usuarioId, String capituloId) async {
    final d = await buscar(usuarioId, capituloId);
    return d?.concluido ?? false;
  }

  // ── Escrita ────────────────────────────────────────────────

  /// Cria o registro de download com status 'pendente'.
  /// Se já existir retorna o existente sem duplicar.
  Future<Download> iniciar(String usuarioId, String capituloId) async {
    final existente = await buscar(usuarioId, capituloId);
    if (existente != null) return existente;

    final novo = Download(
      id:           _uuid.v4(),
      usuarioId:    usuarioId,
      capituloId:   capituloId,
      status:       'pendente',
      criadoEm:     DateTime.now(),
      atualizadoEm: DateTime.now(),
    );

    await _db.insert('downloads', novo.toMap());

    // Tenta enviar ao Supabase imediatamente se online
    _enviarOuEnfileirar(
      usuarioId:  usuarioId,
      registroId: novo.id,
      payload:    novo.toSupabase(),
      operacao:   'INSERT',
    );

    return novo;
  }

  /// Atualiza status, caminho local e tamanho.
  /// Chamado em cada transição: pendente → baixando → concluido | erro
  Future<void> atualizarStatus(
    String usuarioId,
    String capituloId, {
    required String status,
    String? caminhoLocal,
    int? tamanhoBytes,
  }) async {
    final existente = await buscar(usuarioId, capituloId);
    if (existente == null) return;

    final atualizado = existente.copyWith(
      status:       status,
      caminhoLocal: caminhoLocal,
      tamanhoBytes: tamanhoBytes,
    );

    await _db.update(
      'downloads',
      atualizado.toMap(),
      'usuario_id = ? AND capitulo_id = ?',
      [usuarioId, capituloId],
    );

    _enviarOuEnfileirar(
      usuarioId:  usuarioId,
      registroId: existente.id,
      payload:    atualizado.toSupabase(),
      operacao:   'UPDATE',
    );
  }

  /// Remove o download do SQLite e do Supabase.
  /// Uso: quando o usuário exclui o download pelo app.
  Future<void> remover(String usuarioId, String capituloId) async {
    final existente = await buscar(usuarioId, capituloId);
    if (existente == null) return;

    // Remove local primeiro (offline-first)
    await _db.delete(
      'downloads',
      'usuario_id = ? AND capitulo_id = ?',
      [usuarioId, capituloId],
    );

    // Tenta remover no Supabase ou enfileira
    if (await _online()) {
      try {
        await _client.from('downloads').delete().eq('id', existente.id);
        return;
      } catch (_) {}
    }
    await SyncService.instance.enfileirar(
      usuarioId:  usuarioId,
      tabela:     'downloads',
      operacao:   'DELETE',
      registroId: existente.id,
    );
  }

  // ── Helpers ────────────────────────────────────────────────

  /// Tenta enviar ao Supabase; se falhar ou estiver offline, enfileira no sync_log.
  Future<void> _enviarOuEnfileirar({
    required String usuarioId,
    required String registroId,
    required Map<String, dynamic> payload,
    required String operacao,
  }) async {
    if (await _online()) {
      try {
        switch (operacao) {
          case 'INSERT':
            await _client.from('downloads').upsert(payload);
          case 'UPDATE':
            await _client.from('downloads').update(payload).eq('id', registroId);
          case 'DELETE':
            await _client.from('downloads').delete().eq('id', registroId);
        }
        return;
      } catch (_) {}
    }
    await SyncService.instance.enfileirar(
      usuarioId:  usuarioId,
      tabela:     'downloads',
      operacao:   operacao,
      registroId: registroId,
      payload:    payload,
    );
  }

  Future<bool> _online() async {
    final r = await Connectivity().checkConnectivity();
    return r.any((result) => result != ConnectivityResult.none);
  }
}