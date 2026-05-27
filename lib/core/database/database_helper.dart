import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._internal();
  static Database? _db;

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDatabase();
    return _db!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'toonarchive.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
      onOpen: _onOpen,
    );
  }

  /// Habilita chaves estrangeiras toda vez que a conexão é aberta.
  /// O SQLite desliga isso por padrão em cada nova conexão.
  Future<void> _onOpen(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  Future<void> _onCreate(Database db, int version) async {
    final commands = _schema();
    for (final sql in commands) {
      await db.execute(sql);
    }
  }

  /// Retorna todos os comandos CREATE TABLE e CREATE INDEX na ordem correta.
  List<String> _schema() => [
    // ── usuarios ──────────────────────────────────────────────
    '''
    CREATE TABLE IF NOT EXISTS usuarios (
      id            TEXT PRIMARY KEY,
      firebase_uid  TEXT UNIQUE,
      nome          TEXT NOT NULL,
      email         TEXT UNIQUE NOT NULL,
      avatar_url    TEXT,
      role          TEXT NOT NULL DEFAULT 'leitor'
                    CHECK (role IN ('leitor', 'admin', 'moderador')),
      ativo         INTEGER NOT NULL DEFAULT 1 CHECK (ativo IN (0, 1)),
      criado_em     TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
      atualizado_em TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
    )
    ''',

    // ── obras ─────────────────────────────────────────────────
    '''
    CREATE TABLE IF NOT EXISTS obras (
      id              TEXT PRIMARY KEY,
      titulo          TEXT UNIQUE NOT NULL,
      descricao       TEXT,
      genero          TEXT,
      status          TEXT NOT NULL DEFAULT 'em_andamento'
                      CHECK (status IN ('em_andamento','completa','hiato','cancelada')),
      capa_url        TEXT,
      autor           TEXT,
      total_capitulos INTEGER NOT NULL DEFAULT 0 CHECK (total_capitulos >= 0),
      destaque        INTEGER NOT NULL DEFAULT 0 CHECK (destaque IN (0, 1)),
      criado_em       TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
      atualizado_em   TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
    )
    ''',

    // ── capitulos ─────────────────────────────────────────────
    '''
    CREATE TABLE IF NOT EXISTS capitulos (
      id                 TEXT PRIMARY KEY,
      obra_id            TEXT NOT NULL REFERENCES obras(id) ON DELETE CASCADE,
      titulo             TEXT NOT NULL,
      numero             INTEGER NOT NULL CHECK (numero > 0),
      disponivel_offline INTEGER NOT NULL DEFAULT 0 CHECK (disponivel_offline IN (0, 1)),
      criado_em          TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
      UNIQUE (obra_id, numero)
    )
    ''',

    // ── paginas ───────────────────────────────────────────────
    '''
    CREATE TABLE IF NOT EXISTS paginas (
      id           TEXT PRIMARY KEY,
      capitulo_id  TEXT NOT NULL REFERENCES capitulos(id) ON DELETE CASCADE,
      numero       INTEGER NOT NULL CHECK (numero > 0),
      imagem_url   TEXT NOT NULL,
      imagem_local TEXT,
      UNIQUE (capitulo_id, numero)
    )
    ''',

    // ── favoritos ─────────────────────────────────────────────
    '''
    CREATE TABLE IF NOT EXISTS favoritos (
      id         TEXT PRIMARY KEY,
      usuario_id TEXT NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE,
      obra_id    TEXT NOT NULL REFERENCES obras(id)    ON DELETE CASCADE,
      criado_em  TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
      UNIQUE (usuario_id, obra_id)
    )
    ''',

    // ── downloads ─────────────────────────────────────────────
    '''
    CREATE TABLE IF NOT EXISTS downloads (
      id            TEXT PRIMARY KEY,
      usuario_id    TEXT NOT NULL REFERENCES usuarios(id)  ON DELETE CASCADE,
      capitulo_id   TEXT NOT NULL REFERENCES capitulos(id) ON DELETE CASCADE,
      status        TEXT NOT NULL DEFAULT 'pendente'
                    CHECK (status IN ('pendente','baixando','concluido','erro')),
      caminho_local TEXT,
      tamanho_bytes INTEGER CHECK (tamanho_bytes >= 0),
      criado_em     TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
      atualizado_em TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
      UNIQUE (usuario_id, capitulo_id)
    )
    ''',

    // ── progresso_leitura ─────────────────────────────────────
    '''
    CREATE TABLE IF NOT EXISTS progresso_leitura (
      id            TEXT PRIMARY KEY,
      usuario_id    TEXT NOT NULL REFERENCES usuarios(id)  ON DELETE CASCADE,
      obra_id       TEXT NOT NULL REFERENCES obras(id)     ON DELETE CASCADE,
      capitulo_id   TEXT NOT NULL REFERENCES capitulos(id) ON DELETE CASCADE,
      ultima_pagina INTEGER NOT NULL DEFAULT 1 CHECK (ultima_pagina > 0),
      atualizado_em TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
      UNIQUE (usuario_id, obra_id)
    )
    ''',

    // ── historico_leitura ─────────────────────────────────────
    '''
    CREATE TABLE IF NOT EXISTS historico_leitura (
      id           TEXT PRIMARY KEY,
      usuario_id   TEXT NOT NULL REFERENCES usuarios(id)  ON DELETE CASCADE,
      obra_id      TEXT NOT NULL REFERENCES obras(id)     ON DELETE CASCADE,
      capitulo_id  TEXT NOT NULL REFERENCES capitulos(id) ON DELETE CASCADE,
      concluido_em TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
      UNIQUE (usuario_id, capitulo_id)
    )
    ''',

    // ── avaliacoes ────────────────────────────────────────────
    '''
    CREATE TABLE IF NOT EXISTS avaliacoes (
      id         TEXT PRIMARY KEY,
      usuario_id TEXT NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE,
      obra_id    TEXT NOT NULL REFERENCES obras(id)    ON DELETE CASCADE,
      nota       INTEGER NOT NULL CHECK (nota BETWEEN 1 AND 5),
      comentario TEXT,
      criado_em  TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
      UNIQUE (usuario_id, obra_id)
    )
    ''',

    // ── comentarios ───────────────────────────────────────────
    '''
    CREATE TABLE IF NOT EXISTS comentarios (
      id            TEXT PRIMARY KEY,
      usuario_id    TEXT NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE,
      obra_id       TEXT NOT NULL REFERENCES obras(id)    ON DELETE CASCADE,
      parent_id     TEXT REFERENCES comentarios(id)       ON DELETE CASCADE,
      conteudo      TEXT NOT NULL CHECK (length(conteudo) BETWEEN 1 AND 2000),
      likes         INTEGER NOT NULL DEFAULT 0 CHECK (likes >= 0),
      editado       INTEGER NOT NULL DEFAULT 0 CHECK (editado IN (0, 1)),
      criado_em     TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
      atualizado_em TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
    )
    ''',

    // ── sync_log ──────────────────────────────────────────────
    '''
    CREATE TABLE IF NOT EXISTS sync_log (
      id               TEXT PRIMARY KEY,
      usuario_id       TEXT NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE,
      tabela           TEXT NOT NULL,
      operacao         TEXT NOT NULL CHECK (operacao IN ('INSERT','UPDATE','DELETE')),
      registro_id      TEXT NOT NULL,
      payload          TEXT,
      sincronizado     INTEGER NOT NULL DEFAULT 0 CHECK (sincronizado IN (0, 1)),
      criado_em        TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
      sincronizado_em  TEXT
    )
    ''',

    // ── índices ───────────────────────────────────────────────
    'CREATE INDEX IF NOT EXISTS idx_obras_titulo      ON obras (titulo)',
    'CREATE INDEX IF NOT EXISTS idx_obras_destaque    ON obras (destaque)',
    'CREATE INDEX IF NOT EXISTS idx_obras_genero      ON obras (genero)',
    'CREATE INDEX IF NOT EXISTS idx_capitulos_obra    ON capitulos (obra_id, numero)',
    'CREATE INDEX IF NOT EXISTS idx_paginas_capitulo  ON paginas (capitulo_id, numero)',
    'CREATE INDEX IF NOT EXISTS idx_favoritos_usuario ON favoritos (usuario_id)',
    'CREATE INDEX IF NOT EXISTS idx_favoritos_obra    ON favoritos (obra_id)',
    'CREATE INDEX IF NOT EXISTS idx_downloads_usuario ON downloads (usuario_id)',
    'CREATE INDEX IF NOT EXISTS idx_downloads_status  ON downloads (status)',
    'CREATE INDEX IF NOT EXISTS idx_progresso_usuario ON progresso_leitura (usuario_id)',
    'CREATE INDEX IF NOT EXISTS idx_progresso_obra    ON progresso_leitura (obra_id)',
    'CREATE INDEX IF NOT EXISTS idx_historico_usuario ON historico_leitura (usuario_id, concluido_em DESC)',
    'CREATE INDEX IF NOT EXISTS idx_historico_obra    ON historico_leitura (obra_id)',
    'CREATE INDEX IF NOT EXISTS idx_avaliacoes_obra   ON avaliacoes (obra_id)',
    'CREATE INDEX IF NOT EXISTS idx_comentarios_obra  ON comentarios (obra_id, criado_em DESC)',
    'CREATE INDEX IF NOT EXISTS idx_comentarios_pai   ON comentarios (parent_id)',
    'CREATE INDEX IF NOT EXISTS idx_sync_pendente     ON sync_log (usuario_id, sincronizado)',
  ];

  // ── helpers genéricos ──────────────────────────────────────

  Future<int> insert(String table, Map<String, dynamic> data) async {
    final db = await database;
    return await db.insert(table, data, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<int> update(String table, Map<String, dynamic> data, String where, List<dynamic> args) async {
    final db = await database;
    return await db.update(table, data, where: where, whereArgs: args);
  }

  Future<int> delete(String table, String where, List<dynamic> args) async {
    final db = await database;
    return await db.delete(table, where: where, whereArgs: args);
  }

  Future<List<Map<String, dynamic>>> query(
    String table, {
    String? where,
    List<dynamic>? whereArgs,
    String? orderBy,
    int? limit,
  }) async {
    final db = await database;
    return await db.query(table, where: where, whereArgs: whereArgs, orderBy: orderBy, limit: limit);
  }

  Future<List<Map<String, dynamic>>> rawQuery(String sql, [List<dynamic>? args]) async {
    final db = await database;
    return await db.rawQuery(sql, args);
  }

  Future<void> close() async {
    if (_db != null) {
      await _db!.close();
      _db = null;
    }
  }
}