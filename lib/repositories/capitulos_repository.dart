import 'package:connectivity_plus/connectivity_plus.dart';

import '../core/database/database_helper.dart';
import '../core/database/supabase_client.dart';
import '../models/capitulo.dart';
import 'package:sqflite/sqflite.dart';

/// Regras:
/// - Leitura: Supabase online → fallback SQLite
/// - Escrita: apenas admin, direto no Supabase
class CapitulosRepository {
  static final CapitulosRepository instance = CapitulosRepository._();

  CapitulosRepository._();

  final _db = DatabaseHelper.instance;
  final _client = SupabaseClientHelper.client;

  // ─────────────────────────────────────────────
  // LISTAR CAPÍTULOS POR OBRA
  // ─────────────────────────────────────────────
  Future<List<Capitulo>> listarPorObra(String obraId) async {
    if (await _online()) {
      try {
        final rows = await _client
            .from('capitulos')
            .select()
            .eq('obra_id', obraId)
            .order('numero');

        final capitulos = rows.map((r) => Capitulo.fromSupabase(r)).toList();
        await _cachear(capitulos);
        return capitulos;
      } catch (_) {}
    }

    // fallback SQLite
    final rows = await _db.query(
      'capitulos',
      where: 'obra_id = ?',
      whereArgs: [obraId],
      orderBy: 'numero ASC',
    );
    return rows.map(Capitulo.fromMap).toList();
  }

  // ─────────────────────────────────────────────
  // BUSCAR CAPÍTULO POR ID
  // ─────────────────────────────────────────────
  Future<Capitulo?> buscarPorId(String id) async {
    if (await _online()) {
      try {
        final rows = await _client
            .from('capitulos')
            .select()
            .eq('id', id)
            .limit(1);

        if (rows.isNotEmpty) {
          final capitulo = Capitulo.fromSupabase(rows.first);
          await _cachear([capitulo]);
          return capitulo;
        }
      } catch (_) {}
    }

    final rows = await _db.query(
      'capitulos',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (rows.isEmpty) return null;
    return Capitulo.fromMap(rows.first);
  }

  Future<void> marcarOffline(String capituloId) async {
    final db = await _db.database;
    await db.update(
      'capitulos',
      {'disponivel_offline': 1},
      where: 'id = ?',
      whereArgs: [capituloId],
    );
  }

  Future<void> removerOffline(String capituloId) async {
    final db = await _db.database;
    await db.update(
      'capitulos',
      {'disponivel_offline': 0},
      where: 'id = ?',
      whereArgs: [capituloId],
    );
  }

  // ─────────────────────────────────────────────
  // LISTAR OFFLINE
  // ─────────────────────────────────────────────
  Future<List<Capitulo>> listarOffline() async {
    final rows = await _db.query(
      'capitulos',
      where: 'disponivel_offline = ?',
      whereArgs: [1],
      orderBy: 'numero ASC',
    );
    return rows.map(Capitulo.fromMap).toList();
  }

  // ─────────────────────────────────────────────
  // CACHE LOCAL
  //
  // IMPORTANTE: usa INSERT OR IGNORE + UPDATE seletivo em vez de
  // INSERT OR REPLACE para NÃO acionar o ON DELETE CASCADE nas
  // tabelas filhas (downloads, paginas) quando o capítulo já existe.
  // ─────────────────────────────────────────────
  Future<void> _cachear(List<Capitulo> capitulos) async {
    final db = await _db.database;

    for (final capitulo in capitulos) {
      // 1. Tenta inserir — ignora se já existe (preserva disponivel_offline)
      final inserido = await db.insert(
        'capitulos',
        capitulo.toMap(),
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );

      // 2. Se já existia (inserido == 0), atualiza apenas os campos remotos.
      //    Nunca toca em disponivel_offline para não perder o flag de download.
      if (inserido == 0) {
        await db.update(
          'capitulos',
          {
            'titulo':    capitulo.titulo,
            'numero':    capitulo.numero,
            'criado_em': capitulo.criadoEm.toIso8601String(),
            // disponivel_offline é gerenciado localmente — não sobrescrever
          },
          where: 'id = ?',
          whereArgs: [capitulo.id],
        );
      }
    }
  }

  // ─────────────────────────────────────────────
  // ONLINE?
  // ─────────────────────────────────────────────
  Future<bool> _online() async {
    final result = await Connectivity().checkConnectivity();
    return result.any((r) => r != ConnectivityResult.none);
  }
}