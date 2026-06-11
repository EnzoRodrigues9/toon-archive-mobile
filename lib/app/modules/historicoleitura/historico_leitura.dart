class HistoricoLeitura {
  final String id;
  final String usuarioId;
  final String obraId;
  final String capituloId;
  final DateTime concluidoEm;

  const HistoricoLeitura({
    required this.id,
    required this.usuarioId,
    required this.obraId,
    required this.capituloId,
    required this.concluidoEm,
  });

  // ── SQLite ──────────────────────────────────────────────────
  factory HistoricoLeitura.fromMap(Map<String, dynamic> map) => HistoricoLeitura(
    id:          map['id'] as String,
    usuarioId:   map['usuario_id'] as String,
    obraId:      map['obra_id'] as String,
    capituloId:  map['capitulo_id'] as String,
    concluidoEm: DateTime.parse(map['concluido_em'] as String),
  );

  Map<String, dynamic> toMap() => {
    'id':           id,
    'usuario_id':   usuarioId,
    'obra_id':      obraId,
    'capitulo_id':  capituloId,
    'concluido_em': concluidoEm.toIso8601String(),
  };

  // ── Supabase ─────────────────────────────────────────────────
  factory HistoricoLeitura.fromSupabase(Map<String, dynamic> map) => HistoricoLeitura(
    id:          map['id'] as String,
    usuarioId:   map['usuario_id'] as String,
    obraId:      map['obra_id'] as String,
    capituloId:  map['capitulo_id'] as String,
    concluidoEm: DateTime.parse(map['concluido_em'] as String),
  );

  Map<String, dynamic> toSupabase() => {
    'id':           id,
    'usuario_id':   usuarioId,
    'obra_id':      obraId,
    'capitulo_id':  capituloId,
    'concluido_em': concluidoEm.toIso8601String(),
  };
}