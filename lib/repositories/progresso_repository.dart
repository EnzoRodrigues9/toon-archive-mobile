import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:uuid/uuid.dart';
import '../core/database/database_helper.dart';
import '../core/database/supabase_client.dart';
import '../core/sync/sync_service.dart';
import '../models/progresso_leitura.dart';
import '../models/historico_leitura.dart';

/// Gerencia progresso de leitura e histórico de capítulos concluídos.
///
/// Regras:
///   - progresso_leitura: atualizado ao pausar/fechar capítulo (não a cada página)
///   - historico_leitura: inserido apenas ao concluir um capítulo
///   - Retenção local: mantém os últimos 100 registros por usuário
class ProgressoRepository {
  static final ProgressoRepository instance = ProgressoRepository._();
  ProgressoRepository._();

  static const int _limiteHistorico = 100;

  final _db     = DatabaseHelper.instance;
  final _client = SupabaseClientHelper.client;
  final _uuid   = const Uuid();

  // ── Progresso ──────────────────────────────────────────────

  /// Retorna onde o usuário parou em uma obra, ou null se nunca leu.
  Future<ProgressoLeitura?> buscarProgresso(String usuarioId, String obraId) async {
    final rows = await _db.query('progresso_leitura',
        where: 'usuario_id = ? AND obra_id = ?',
        whereArgs: [usuarioId, obraId]);
    return rows.isNotEmpty ? ProgressoLeitura.fromMap(rows.first) : null;
  }

  /// Salva ou atualiza onde o usuário está.
  /// Chame ao pausar a leitura ou ao fechar o capítulo — não a cada virada de página.
  Future<void> salvarProgresso({
    required String usuarioId,
    required String obraId,
    required String capituloId,
    required int ultimaPagina,
  }) async {
    final existente = await buscarProgresso(usuarioId, obraId);
    final now = DateTime.now().toIso8601String();

    if (existente != null) {
      // UPDATE
      final atualizado = existente.copyWith(
        capituloId:  capituloId,
        ultimaPagina: ultimaPagina,
      );
      await _db.update('progresso_leitura', atualizado.toMap(),
          'usuario_id = ? AND obra_id = ?', [usuarioId, obraId]);

      _enviarOuEnfileirar(
        usuarioId:  usuarioId,
        tabela:     'progresso_leitura',
        operacao:   'UPDATE',
        registroId: existente.id,
        payload:    atualizado.toSupabase(),
      );
    } else {
      // INSERT
      final novo = ProgressoLeitura(
        id:           _uuid.v4(),
        usuarioId:    usuarioId,
        obraId:       obraId,
        capituloId:   capituloId,
        ultimaPagina: ultimaPagina,
        atualizadoEm: DateTime.now(),
      );
      await _db.insert('progresso_leitura', novo.toMap());

      _enviarOuEnfileirar(
        usuarioId:  usuarioId,
        tabela:     'progresso_leitura',
        operacao:   'INSERT',
        registroId: novo.id,
        payload:    novo.toSupabase(),
      );
    }
  }

  // ── Histórico ──────────────────────────────────────────────

  Future<List<HistoricoLeitura>> listarHistorico(String usuarioId) async {
    final rows = await _db.query('historico_leitura',
        where:    'usuario_id = ?',
        whereArgs: [usuarioId],
        orderBy:  'concluido_em DESC',
        limit:    _limiteHistorico);
    return rows.map(HistoricoLeitura.fromMap).toList();
  }

  /// Registra um capítulo como concluído.
  /// Chame apenas quando o usuário chegar na última página.
  Future<void> marcarConcluido({
    required String usuarioId,
    required String obraId,
    required String capituloId,
  }) async {
    // Ignora se já está no histórico
    final jaExiste = await _db.query('historico_leitura',
        where:     'usuario_id = ? AND capitulo_id = ?',
        whereArgs: [usuarioId, capituloId]);
    if (jaExiste.isNotEmpty) return;

    final novo = HistoricoLeitura(
      id:          _uuid.v4(),
      usuarioId:   usuarioId,
      obraId:      obraId,
      capituloId:  capituloId,
      concluidoEm: DateTime.now(),
    );

    await _db.insert('historico_leitura', novo.toMap());
    await _aplicarRetencao(usuarioId);

    _enviarOuEnfileirar(
      usuarioId:  usuarioId,
      tabela:     'historico_leitura',
      operacao:   'INSERT',
      registroId: novo.id,
      payload:    novo.toSupabase(),
    );
  }

  /// Mantém apenas os últimos [_limiteHistorico] registros por usuário.
  Future<void> _aplicarRetencao(String usuarioId) async {
    final db = await DatabaseHelper.instance.database;
    await db.rawDelete('''
      DELETE FROM historico_leitura
      WHERE usuario_id = ?
        AND id NOT IN (
          SELECT id FROM historico_leitura
          WHERE usuario_id = ?
          ORDER BY concluido_em DESC
          LIMIT ?
        )
    ''', [usuarioId, usuarioId, _limiteHistorico]);
  }

  // ── Helpers ────────────────────────────────────────────────

  Future<void> _enviarOuEnfileirar({
    required String usuarioId,
    required String tabela,
    required String operacao,
    required String registroId,
    Map<String, dynamic>? payload,
  }) async {
    if (await _online()) {
      try {
        switch (operacao) {
          case 'INSERT':
            await _client.from(tabela).upsert(payload!);
          case 'UPDATE':
            await _client.from(tabela).update(payload!).eq('id', registroId);
          case 'DELETE':
            await _client.from(tabela).delete().eq('id', registroId);
        }
        return;
      } catch (_) {}
    }
    await SyncService.instance.enfileirar(
      usuarioId:  usuarioId,
      tabela:     tabela,
      operacao:   operacao,
      registroId: registroId,
      payload:    payload,
    );
  }

  Future<bool> _online() async {
    final r = await Connectivity().checkConnectivity();
    return r != ConnectivityResult.none;
  }
}