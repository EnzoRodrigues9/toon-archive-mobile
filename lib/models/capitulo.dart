class Capitulo {
  final String id;
  final String obraId;
  final String titulo;
  final int numero;
  final bool disponivelOffline;
  final DateTime criadoEm;

  const Capitulo({
    required this.id,
    required this.obraId,
    required this.titulo,
    required this.numero,
    this.disponivelOffline = false,
    required this.criadoEm,
  });

  // ── SQLite ──────────────────────────────────────────────────
  factory Capitulo.fromMap(Map<String, dynamic> map) => Capitulo(
    id:                 map['id'] as String,
    obraId:             map['obra_id'] as String,
    titulo:             map['titulo'] as String,
    numero:             map['numero'] as int,
    disponivelOffline:  (map['disponivel_offline'] as int? ?? 0) == 1,
    criadoEm:           DateTime.parse(map['criado_em'] as String),
  );

  Map<String, dynamic> toMap() => {
    'id':                 id,
    'obra_id':            obraId,
    'titulo':             titulo,
    'numero':             numero,
    'disponivel_offline': disponivelOffline ? 1 : 0,
    'criado_em':          criadoEm.toIso8601String(),
  };

  // ── Supabase ─────────────────────────────────────────────────
  factory Capitulo.fromSupabase(Map<String, dynamic> map) => Capitulo(
    id:                 map['id'] as String,
    obraId:             map['obra_id'] as String,
    titulo:             map['titulo'] as String,
    numero:             map['numero'] as int,
    disponivelOffline:  map['disponivel_offline'] as bool? ?? false,
    criadoEm:           DateTime.parse(map['criado_em'] as String),
  );

  Map<String, dynamic> toSupabase() => {
    'id':                  id,
    'obra_id':             obraId,
    'titulo':              titulo,
    'numero':              numero,
    'disponivel_offline':  disponivelOffline,
    'criado_em':           criadoEm.toIso8601String(),
  };
}