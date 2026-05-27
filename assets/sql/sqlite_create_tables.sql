-- ============================================================
--  ToonArchive — SQLite (offline)
--  Executado pelo sqflite no Flutter via DatabaseHelper.onCreate.
--  Atualização: historico_leitura separado em duas tabelas:
--    - progresso_leitura → onde o usuário está agora
--    - historico_leitura → capítulos concluídos (com retenção)
-- ============================================================
--
--  DIFERENÇAS em relação ao Supabase:
--  - UUID        → TEXT (gerado no Dart com pacote uuid)
--  - TIMESTAMPTZ → TEXT (ISO-8601, ex.: '2026-01-01T10:00:00Z')
--  - BOOLEAN     → INTEGER (0 = false, 1 = true)
--  - ENUM        → TEXT + CHECK (coluna IN (...))
--  - JSONB       → TEXT (JSON serializado como string)
--  - BIGINT      → INTEGER
--  - SMALLINT    → INTEGER
--  - NOW()       → CURRENT_TIMESTAMP
--  - Sem RLS, sem extensões, sem triggers de função
--  - Retenção do historico_leitura feita na camada Dart
--  - sync_log    → exclusiva do SQLite
-- ============================================================


-- ------------------------------------------------------------
--  PRAGMA: habilita chaves estrangeiras (desligado por padrão).
--  Execute isso TODA VEZ que abrir a conexão no DatabaseHelper,
--  não apenas no onCreate.
-- ------------------------------------------------------------
PRAGMA foreign_keys = ON;


-- ------------------------------------------------------------
--  TABELA: usuarios
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS usuarios (
    id            TEXT     PRIMARY KEY,
    firebase_uid  TEXT     UNIQUE,
    nome          TEXT     NOT NULL,
    email         TEXT     UNIQUE NOT NULL,
    avatar_url    TEXT,
    role          TEXT     NOT NULL DEFAULT 'leitor'
                           CHECK (role IN ('leitor', 'admin', 'moderador')),
    ativo         INTEGER  NOT NULL DEFAULT 1
                           CHECK (ativo IN (0, 1)),
    criado_em     TEXT     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    atualizado_em TEXT     NOT NULL DEFAULT CURRENT_TIMESTAMP
);


-- ------------------------------------------------------------
--  TABELA: obras
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS obras (
    id              TEXT     PRIMARY KEY,
    titulo          TEXT     UNIQUE NOT NULL,
    descricao       TEXT,
    genero          TEXT,
    status          TEXT     NOT NULL DEFAULT 'em_andamento'
                             CHECK (status IN ('em_andamento', 'completa', 'hiato', 'cancelada')),
    capa_url        TEXT,
    autor           TEXT,
    total_capitulos INTEGER  NOT NULL DEFAULT 0 CHECK (total_capitulos >= 0),
    destaque        INTEGER  NOT NULL DEFAULT 0 CHECK (destaque IN (0, 1)),
    criado_em       TEXT     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    atualizado_em   TEXT     NOT NULL DEFAULT CURRENT_TIMESTAMP
);


-- ------------------------------------------------------------
--  TABELA: capitulos
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS capitulos (
    id                 TEXT     PRIMARY KEY,
    obra_id            TEXT     NOT NULL REFERENCES obras(id) ON DELETE CASCADE,
    titulo             TEXT     NOT NULL,
    numero             INTEGER  NOT NULL CHECK (numero > 0),
    disponivel_offline INTEGER  NOT NULL DEFAULT 0 CHECK (disponivel_offline IN (0, 1)),
    criado_em          TEXT     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (obra_id, numero)
);


-- ------------------------------------------------------------
--  TABELA: paginas
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS paginas (
    id            TEXT     PRIMARY KEY,
    capitulo_id   TEXT     NOT NULL REFERENCES capitulos(id) ON DELETE CASCADE,
    numero        INTEGER  NOT NULL CHECK (numero > 0),
    imagem_url    TEXT     NOT NULL,
    imagem_local  TEXT,
    UNIQUE (capitulo_id, numero)
);


-- ------------------------------------------------------------
--  TABELA: favoritos
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS favoritos (
    id          TEXT     PRIMARY KEY,
    usuario_id  TEXT     NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE,
    obra_id     TEXT     NOT NULL REFERENCES obras(id)    ON DELETE CASCADE,
    criado_em   TEXT     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (usuario_id, obra_id)
);


-- ------------------------------------------------------------
--  TABELA: downloads
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS downloads (
    id            TEXT     PRIMARY KEY,
    usuario_id    TEXT     NOT NULL REFERENCES usuarios(id)  ON DELETE CASCADE,
    capitulo_id   TEXT     NOT NULL REFERENCES capitulos(id) ON DELETE CASCADE,
    status        TEXT     NOT NULL DEFAULT 'pendente'
                           CHECK (status IN ('pendente', 'baixando', 'concluido', 'erro')),
    caminho_local TEXT,
    tamanho_bytes INTEGER  CHECK (tamanho_bytes >= 0),
    criado_em     TEXT     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    atualizado_em TEXT     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (usuario_id, capitulo_id)
);


-- ------------------------------------------------------------
--  TABELA: progresso_leitura
--
--  Guarda APENAS onde o usuário está agora em cada obra.
--  Uma linha por (usuario, obra) — volume sempre controlado.
--  Atualizada ao pausar ou fechar o capítulo, não a cada página.
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS progresso_leitura (
    id            TEXT     PRIMARY KEY,
    usuario_id    TEXT     NOT NULL REFERENCES usuarios(id)  ON DELETE CASCADE,
    obra_id       TEXT     NOT NULL REFERENCES obras(id)     ON DELETE CASCADE,
    capitulo_id   TEXT     NOT NULL REFERENCES capitulos(id) ON DELETE CASCADE,
    ultima_pagina INTEGER  NOT NULL DEFAULT 1 CHECK (ultima_pagina > 0),
    atualizado_em TEXT     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (usuario_id, obra_id)
);


-- ------------------------------------------------------------
--  TABELA: historico_leitura
--
--  Registra apenas capítulos CONCLUÍDOS.
--  Inserção única por capítulo — nunca atualiza.
--
--  RETENÇÃO NO DART:
--  O SQLite não suporta triggers com DELETE baseado em COUNT
--  da mesma forma que o PostgreSQL. Por isso, aplique o limite
--  de 100 registros diretamente no DatabaseHelper após cada
--  INSERT, usando a query abaixo:
--
--    DELETE FROM historico_leitura
--    WHERE usuario_id = ?
--      AND id NOT IN (
--        SELECT id FROM historico_leitura
--        WHERE usuario_id = ?
--        ORDER BY concluido_em DESC
--        LIMIT 100
--      );
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS historico_leitura (
    id           TEXT     PRIMARY KEY,
    usuario_id   TEXT     NOT NULL REFERENCES usuarios(id)  ON DELETE CASCADE,
    obra_id      TEXT     NOT NULL REFERENCES obras(id)     ON DELETE CASCADE,
    capitulo_id  TEXT     NOT NULL REFERENCES capitulos(id) ON DELETE CASCADE,
    concluido_em TEXT     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (usuario_id, capitulo_id)
);


-- ------------------------------------------------------------
--  TABELA: avaliacoes
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS avaliacoes (
    id          TEXT     PRIMARY KEY,
    usuario_id  TEXT     NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE,
    obra_id     TEXT     NOT NULL REFERENCES obras(id)    ON DELETE CASCADE,
    nota        INTEGER  NOT NULL CHECK (nota BETWEEN 1 AND 5),
    comentario  TEXT,
    criado_em   TEXT     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (usuario_id, obra_id)
);


-- ------------------------------------------------------------
--  TABELA: comentarios
--  Somente cache de leitura no SQLite.
--  Criação de novos comentários exige conexão com Supabase.
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS comentarios (
    id            TEXT     PRIMARY KEY,
    usuario_id    TEXT     NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE,
    obra_id       TEXT     NOT NULL REFERENCES obras(id)    ON DELETE CASCADE,
    parent_id     TEXT     REFERENCES comentarios(id)       ON DELETE CASCADE,
    conteudo      TEXT     NOT NULL CHECK (length(conteudo) BETWEEN 1 AND 2000),
    likes         INTEGER  NOT NULL DEFAULT 0 CHECK (likes >= 0),
    editado       INTEGER  NOT NULL DEFAULT 0 CHECK (editado IN (0, 1)),
    criado_em     TEXT     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    atualizado_em TEXT     NOT NULL DEFAULT CURRENT_TIMESTAMP
);


-- ------------------------------------------------------------
--  TABELA: sync_log  ← EXCLUSIVA DO SQLITE
--
--  Fila de operações feitas offline.
--  O SyncService drena esta tabela ao detectar conexão.
--
--  Fluxo:
--    1. Usuário faz ação offline (favoritar, marcar progresso...)
--    2. App salva na tabela correspondente (SQLite)
--       + insere uma linha em sync_log com o payload JSON
--    3. Ao reconectar, SyncService lê WHERE sincronizado = 0
--    4. Envia cada operação ao Supabase na ordem de criado_em
--    5. Marca sincronizado = 1 e preenche sincronizado_em
--
--  Tabelas que geram entradas no sync_log:
--    favoritos, downloads, progresso_leitura, historico_leitura,
--    avaliacoes
--
--  Tabelas que NÃO geram entradas (somente leitura local):
--    obras, capitulos, paginas, comentarios
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS sync_log (
    id               TEXT     PRIMARY KEY,
    usuario_id       TEXT     NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE,
    tabela           TEXT     NOT NULL,
    operacao         TEXT     NOT NULL CHECK (operacao IN ('INSERT', 'UPDATE', 'DELETE')),
    registro_id      TEXT     NOT NULL,
    payload          TEXT,
    sincronizado     INTEGER  NOT NULL DEFAULT 0 CHECK (sincronizado IN (0, 1)),
    criado_em        TEXT     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    sincronizado_em  TEXT
);


-- ------------------------------------------------------------
--  ÍNDICES
-- ------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_obras_titulo       ON obras (titulo);
CREATE INDEX IF NOT EXISTS idx_obras_destaque     ON obras (destaque);
CREATE INDEX IF NOT EXISTS idx_obras_genero       ON obras (genero);
CREATE INDEX IF NOT EXISTS idx_capitulos_obra     ON capitulos (obra_id, numero);
CREATE INDEX IF NOT EXISTS idx_paginas_capitulo   ON paginas (capitulo_id, numero);
CREATE INDEX IF NOT EXISTS idx_favoritos_usuario  ON favoritos (usuario_id);
CREATE INDEX IF NOT EXISTS idx_favoritos_obra     ON favoritos (obra_id);
CREATE INDEX IF NOT EXISTS idx_downloads_usuario  ON downloads (usuario_id);
CREATE INDEX IF NOT EXISTS idx_downloads_status   ON downloads (status);
CREATE INDEX IF NOT EXISTS idx_progresso_usuario  ON progresso_leitura (usuario_id);
CREATE INDEX IF NOT EXISTS idx_progresso_obra     ON progresso_leitura (obra_id);
CREATE INDEX IF NOT EXISTS idx_historico_usuario  ON historico_leitura (usuario_id, concluido_em DESC);
CREATE INDEX IF NOT EXISTS idx_historico_obra     ON historico_leitura (obra_id);
CREATE INDEX IF NOT EXISTS idx_avaliacoes_obra    ON avaliacoes (obra_id);
CREATE INDEX IF NOT EXISTS idx_comentarios_obra   ON comentarios (obra_id, criado_em DESC);
CREATE INDEX IF NOT EXISTS idx_comentarios_pai    ON comentarios (parent_id);
CREATE INDEX IF NOT EXISTS idx_sync_pendente      ON sync_log (usuario_id, sincronizado);


-- ============================================================
--  FIM — sqlite_create_tables.sql
-- ============================================================