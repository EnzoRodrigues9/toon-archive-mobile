class ProgressoLeitura {
  final String id;
  final String usuarioId;
  final String obraId;
  final String capituloId;
  final int ultimaPagina;
  final DateTime atualizadoEm;

  const ProgressoLeitura({
    required this.id,
    required this.usuarioId,
    required this.obraId,
    required this.capituloId,
    this.ultimaPagina = 1,
    required this.atualizadoEm,
  });

  // ── SQLite ──────────────────────────────────────────────────
  factory ProgressoLeitura.fromMap(Map<String, dynamic> map) => ProgressoLeitura(
    id:            map['id'] as String,
    usuarioId:     map['usuario_id'] as String,
    obraId:        map['obra_id'] as String,
    capituloId:    map['capitulo_id'] as String,
    ultimaPagina:  map['ultima_pagina'] as int? ?? 1,
    atualizadoEm:  DateTime.parse(map['atualizado_em'] as String),
  );

  Map<String, dynamic> toMap() => {
    'id':            id,
    'usuario_id':    usuarioId,
    'obra_id':       obraId,
    'capitulo_id':   capituloId,
    'ultima_pagina': ultimaPagina,
    'atualizado_em': atualizadoEm.toIso8601String(),
  };

  // ── Supabase ─────────────────────────────────────────────────
  factory ProgressoLeitura.fromSupabase(Map<String, dynamic> map) => ProgressoLeitura(
    id:            map['id'] as String,
    usuarioId:     map['usuario_id'] as String,
    obraId:        map['obra_id'] as String,
    capituloId:    map['capitulo_id'] as String,
    ultimaPagina:  map['ultima_pagina'] as int? ?? 1,
    atualizadoEm:  DateTime.parse(map['atualizado_em'] as String),
  );

  Map<String, dynamic> toSupabase() => {
    'id':            id,
    'usuario_id':    usuarioId,
    'obra_id':       obraId,
    'capitulo_id':   capituloId,
    'ultima_pagina': ultimaPagina,
    'atualizado_em': atualizadoEm.toIso8601String(),
  };

  ProgressoLeitura copyWith({String? capituloId, int? ultimaPagina}) =>
    ProgressoLeitura(
      id:            id,
      usuarioId:     usuarioId,
      obraId:        obraId,
      capituloId:    capituloId  ?? this.capituloId,
      ultimaPagina:  ultimaPagina ?? this.ultimaPagina,
      atualizadoEm:  DateTime.now(),
    );
}