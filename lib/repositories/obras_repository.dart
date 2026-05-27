import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:sqflite/sqflite.dart';
import '../core/database/database_helper.dart';
import '../core/database/supabase_client.dart';
import '../models/obra.dart';
import 'package:flutter/foundation.dart';

/// Regra geral deste repository:
/// - Leitura: tenta Supabase (online) → cai para SQLite (offline)
/// - Escrita: apenas admins, direto no Supabase (obras não são editadas offline)
class ObrasRepository {
  static final ObrasRepository instance = ObrasRepository._();
  ObrasRepository._();

  final _db     = DatabaseHelper.instance;
  final _client = SupabaseClientHelper.client;

  // ── Leitura ────────────────────────────────────────────────

  Future<List<Obra>> listarTodas() async {
    if (await _online()) {
      try {
        final rows = await _client.from('obras').select().order('titulo');
        final obras = rows.map((r) => Obra.fromSupabase(r)).toList();
        await _cachear(obras);
        return obras;
      } catch (e) {
        debugPrint('ERRO OBRAS: $e');
      }
    }
    final rows = await _db.query('obras', orderBy: 'titulo ASC');
    return rows.map(Obra.fromMap).toList();
  }

  Future<List<Obra>> listarDestaques() async {
    if (await _online()) {
      try {
        final rows = await _client
            .from('obras')
            .select()
            .eq('destaque', true)
            .order('titulo');
        final obras = rows.map((r) => Obra.fromSupabase(r)).toList();
        await _cachear(obras);
        return obras;
      } catch (_) {}
    }
    final rows = await _db.query('obras',
        where: 'destaque = ?', whereArgs: [1], orderBy: 'titulo ASC');
    return rows.map(Obra.fromMap).toList();
  }

  Future<Obra?> buscarPorId(String id) async {
    if (await _online()) {
      try {
        final rows =
            await _client.from('obras').select().eq('id', id).limit(1);
        if (rows.isNotEmpty) {
          final obra = Obra.fromSupabase(rows.first);
          await _cachear([obra]);
          return obra;
        }
      } catch (_) {}
    }
    final rows = await _db.query('obras', where: 'id = ?', whereArgs: [id]);
    return rows.isNotEmpty ? Obra.fromMap(rows.first) : null;
  }

  Future<List<Obra>> buscarPorTitulo(String termo) async {
    if (await _online()) {
      try {
        final rows = await _client
            .from('obras')
            .select()
            .ilike('titulo', '%$termo%');
        final obras = rows.map((r) => Obra.fromSupabase(r)).toList();
        await _cachear(obras);
        return obras;
      } catch (_) {}
    }
    final rows = await _db.query('obras',
        where: 'titulo LIKE ?', whereArgs: ['%$termo%']);
    return rows.map(Obra.fromMap).toList();
  }

  // ── Cache local ────────────────────────────────────────────
  //
  // Usa INSERT OR IGNORE + UPDATE seletivo para não acionar
  // ON DELETE CASCADE em capitulos/downloads ao recarregar dados remotos.

  Future<void> _cachear(List<Obra> obras) async {
    final db = await _db.database;

    for (final obra in obras) {
      final inserido = await db.insert(
        'obras',
        obra.toMap(),
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );

      if (inserido == 0) {
        // Atualiza apenas os campos que vêm do servidor remoto
        await db.update(
          'obras',
          {
            'titulo':          obra.titulo,
            'descricao':       obra.descricao,
            'genero':          obra.genero,
            'status':          obra.status,
            'capa_url':        obra.capaUrl,
            'autor':           obra.autor,
            'total_capitulos': obra.totalCapitulos,
            'destaque':        obra.destaque ? 1 : 0,
            'atualizado_em':   obra.atualizadoEm.toIso8601String(),
          },
          where: 'id = ?',
          whereArgs: [obra.id],
        );
      }
    }
  }

  // ── Helpers ────────────────────────────────────────────────

  Future<bool> _online() async {
    final result = await Connectivity().checkConnectivity();
    return result != ConnectivityResult.none;
  }
}