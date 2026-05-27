class Usuario {
  final String id;
  final String? firebaseUid;
  final String nome;
  final String email;
  final String? avatarUrl;
  final String role;
  final bool ativo;
  final DateTime criadoEm;
  final DateTime atualizadoEm;

  const Usuario({
    required this.id,
    this.firebaseUid,
    required this.nome,
    required this.email,
    this.avatarUrl,
    this.role = 'leitor',
    this.ativo = true,
    required this.criadoEm,
    required this.atualizadoEm,
  });

  bool get isAdmin => role == 'admin';
  bool get isModerador => role == 'moderador';

  // ── SQLite ──────────────────────────────────────────────────
  factory Usuario.fromMap(Map<String, dynamic> map) => Usuario(
    id:            map['id'] as String,
    firebaseUid:   map['firebase_uid'] as String?,
    nome:          map['nome'] as String,
    email:         map['email'] as String,
    avatarUrl:     map['avatar_url'] as String?,
    role:          map['role'] as String? ?? 'leitor',
    ativo:         (map['ativo'] as int? ?? 1) == 1,
    criadoEm:      DateTime.parse(map['criado_em'] as String),
    atualizadoEm:  DateTime.parse(map['atualizado_em'] as String),
  );

  Map<String, dynamic> toMap() => {
    'id':            id,
    'firebase_uid':  firebaseUid,
    'nome':          nome,
    'email':         email,
    'avatar_url':    avatarUrl,
    'role':          role,
    'ativo':         ativo ? 1 : 0,
    'criado_em':     criadoEm.toIso8601String(),
    'atualizado_em': atualizadoEm.toIso8601String(),
  };

  // ── Supabase ─────────────────────────────────────────────────
  factory Usuario.fromSupabase(Map<String, dynamic> map) => Usuario(
    id:            map['id'] as String,
    firebaseUid:   map['firebase_uid'] as String?,
    nome:          map['nome'] as String,
    email:         map['email'] as String,
    avatarUrl:     map['avatar_url'] as String?,
    role:          map['role'] as String? ?? 'leitor',
    ativo:         map['ativo'] as bool? ?? true,
    criadoEm:      DateTime.parse(map['criado_em'] as String),
    atualizadoEm:  DateTime.parse(map['atualizado_em'] as String),
  );

  Map<String, dynamic> toSupabase() => {
    'id':            id,
    'firebase_uid':  firebaseUid,
    'nome':          nome,
    'email':         email,
    'avatar_url':    avatarUrl,
    'role':          role,
    'ativo':         ativo,
    'criado_em':     criadoEm.toIso8601String(),
    'atualizado_em': atualizadoEm.toIso8601String(),
  };

  Usuario copyWith({
    String? nome,
    String? avatarUrl,
    String? role,
    bool? ativo,
  }) => Usuario(
    id:            id,
    firebaseUid:   firebaseUid,
    nome:          nome ?? this.nome,
    email:         email,
    avatarUrl:     avatarUrl ?? this.avatarUrl,
    role:          role ?? this.role,
    ativo:         ativo ?? this.ativo,
    criadoEm:      criadoEm,
    atualizadoEm:  DateTime.now(),
  );
}