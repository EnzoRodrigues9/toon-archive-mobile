class Download {
  final String id;
  final String usuarioId;
  final String capituloId;
  final String status;
  final String? caminhoLocal;
  final int? tamanhoBytes;
  final DateTime criadoEm;
  final DateTime atualizadoEm;

  const Download({
    required this.id,
    required this.usuarioId,
    required this.capituloId,
    this.status = 'pendente',
    this.caminhoLocal,
    this.tamanhoBytes,
    required this.criadoEm,
    required this.atualizadoEm,
  });

  bool get concluido  => status == 'concluido';
  bool get comErro    => status == 'erro';
  bool get baixando   => status == 'baixando';

  // ── SQLite ──────────────────────────────────────────────────
  factory Download.fromMap(Map<String, dynamic> map) => Download(
    id:            map['id'] as String,
    usuarioId:     map['usuario_id'] as String,
    capituloId:    map['capitulo_id'] as String,
    status:        map['status'] as String? ?? 'pendente',
    caminhoLocal:  map['caminho_local'] as String?,
    tamanhoBytes:  map['tamanho_bytes'] as int?,
    criadoEm:      DateTime.parse(map['criado_em'] as String),
    atualizadoEm:  DateTime.parse(map['atualizado_em'] as String),
  );

  Map<String, dynamic> toMap() => {
    'id':             id,
    'usuario_id':     usuarioId,
    'capitulo_id':    capituloId,
    'status':         status,
    'caminho_local':  caminhoLocal,
    'tamanho_bytes':  tamanhoBytes,
    'criado_em':      criadoEm.toIso8601String(),
    'atualizado_em':  atualizadoEm.toIso8601String(),
  };

  // ── Supabase ─────────────────────────────────────────────────
  factory Download.fromSupabase(Map<String, dynamic> map) => Download(
    id:            map['id'] as String,
    usuarioId:     map['usuario_id'] as String,
    capituloId:    map['capitulo_id'] as String,
    status:        map['status'] as String? ?? 'pendente',
    caminhoLocal:  map['caminho_local'] as String?,
    tamanhoBytes:  map['tamanho_bytes'] as int?,
    criadoEm:      DateTime.parse(map['criado_em'] as String),
    atualizadoEm:  DateTime.parse(map['atualizado_em'] as String),
  );

  Map<String, dynamic> toSupabase() => {
    'id':             id,
    'usuario_id':     usuarioId,
    'capitulo_id':    capituloId,
    'status':         status,
    'caminho_local':  caminhoLocal,
    'tamanho_bytes':  tamanhoBytes,
    'criado_em':      criadoEm.toIso8601String(),
    'atualizado_em':  atualizadoEm.toIso8601String(),
  };

  Download copyWith({String? status, String? caminhoLocal, int? tamanhoBytes}) =>
    Download(
      id:            id,
      usuarioId:     usuarioId,
      capituloId:    capituloId,
      status:        status        ?? this.status,
      caminhoLocal:  caminhoLocal  ?? this.caminhoLocal,
      tamanhoBytes:  tamanhoBytes  ?? this.tamanhoBytes,
      criadoEm:      criadoEm,
      atualizadoEm:  DateTime.now(),
    );
}