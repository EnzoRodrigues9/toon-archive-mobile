import 'dart:async';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:toonarchive/app/core/database/database_helper.dart';
import 'package:toonarchive/app/core/database/supabase_client.dart';

/// Monitora a conectividade e sincroniza o sync_log com o Supabase
/// sempre que o dispositivo volta a ficar online.
class SyncService {
  static final SyncService instance = SyncService._internal();
  SyncService._internal();

  StreamSubscription<List<ConnectivityResult>>? _subscription;
  bool _syncing = false;

  /// Inicie no main() após inicializar Supabase e SQLite.
  void start() {
    _subscription = Connectivity()
        .onConnectivityChanged
        .listen((results) async {
      final online = results.any((r) => r != ConnectivityResult.none);
      if (online) await syncPendentes();
    });
  }

  void stop() {
    _subscription?.cancel();
    _subscription = null;
  }

  /// Drena todas as entradas pendentes do sync_log em ordem cronológica.
  Future<void> syncPendentes() async {
    if (_syncing) return;
    _syncing = true;

    try {
      final db = DatabaseHelper.instance;
      final pendentes = await db.query(
        'sync_log',
        where: 'sincronizado = ?',
        whereArgs: [0],
        orderBy: 'criado_em ASC',
      );

      for (final entrada in pendentes) {
        final sucesso = await _processar(entrada);
        if (sucesso) {
          await db.update(
            'sync_log',
            {
              'sincronizado': 1,
              'sincronizado_em': DateTime.now().toIso8601String(),
            },
            'id = ?',
            [entrada['id']],
          );
        }
      }
    } finally {
      _syncing = false;
    }
  }

  Future<bool> _processar(Map<String, dynamic> entrada) async {
    try {
      final tabela    = entrada['tabela'] as String;
      final operacao  = entrada['operacao'] as String;
      final payload   = entrada['payload'] != null
          ? jsonDecode(entrada['payload'] as String) as Map<String, dynamic>
          : <String, dynamic>{};
      final registroId = entrada['registro_id'] as String;
      final client     = SupabaseClientHelper.client;

      switch (operacao) {
        case 'INSERT':
          await client.from(tabela).upsert(payload);
        case 'UPDATE':
          await client.from(tabela).update(payload).eq('id', registroId);
        case 'DELETE':
          await client.from(tabela).delete().eq('id', registroId);
      }
      return true;
    } on PostgrestException catch (e) {
      // Conflito de unicidade já resolvido remotamente — considera sincronizado
      if (e.code == '23505') return true;
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Enfileira uma operação no sync_log para ser enviada ao Supabase.
  /// Chame isso toda vez que fizer uma escrita offline em dado do usuário.
  Future<void> enfileirar({
    required String usuarioId,
    required String tabela,
    required String operacao,
    required String registroId,
    Map<String, dynamic>? payload,
  }) async {
    final db = DatabaseHelper.instance;
    await db.insert('sync_log', {
      'id':          _uuid(),
      'usuario_id':  usuarioId,
      'tabela':      tabela,
      'operacao':    operacao,
      'registro_id': registroId,
      'payload':     payload != null ? jsonEncode(payload) : null,
      'sincronizado': 0,
      'criado_em':   DateTime.now().toIso8601String(),
    });
  }

  /// UUID v4 simples sem dependência extra.
  String _uuid() {
    // Se você já tem o pacote uuid no pubspec, substitua por:
    // return const Uuid().v4();
    final now = DateTime.now().microsecondsSinceEpoch;
    return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replaceAllMapped(
      RegExp(r'[xy]'),
      (m) {
        final v = m.group(0) == 'x'
            ? (now + (now * 0.1).round()) % 16
            : ((now + (now * 0.1).round()) % 16 & 0x3 | 0x8);
        return v.toRadixString(16);
      },
    );
  }
}