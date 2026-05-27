class Obra {
  final String id;
  final String titulo;
  final String? descricao;
  final String? genero;
  final String status;
  final String? capaUrl;
  final String? bannerUrl; // <-- novo
  final String? autor;
  final int totalCapitulos;
  final bool destaque;
  final DateTime criadoEm;
  final DateTime atualizadoEm;

  const Obra({
    required this.id,
    required this.titulo,
    this.descricao,
    this.genero,
    this.status = 'em_andamento',
    this.capaUrl,
    this.bannerUrl, // <-- novo
    this.autor,
    this.totalCapitulos = 0,
    this.destaque = false,
    required this.criadoEm,
    required this.atualizadoEm,
  });

  factory Obra.fromMap(Map<String, dynamic> map) => Obra(
    id:             map['id'] as String,
    titulo:         map['titulo'] as String,
    descricao:      map['descricao'] as String?,
    genero:         map['genero'] as String?,
    status:         map['status'] as String? ?? 'em_andamento',
    capaUrl:        map['capa_url'] as String?,
    bannerUrl:      map['banner_url'] as String?, // <-- novo
    autor:          map['autor'] as String?,
    totalCapitulos: map['total_capitulos'] as int? ?? 0,
    destaque:       (map['destaque'] as int? ?? 0) == 1,
    criadoEm:       DateTime.parse(map['criado_em'] as String),
    atualizadoEm:   DateTime.parse(map['atualizado_em'] as String),
  );

  Map<String, dynamic> toMap() => {
    'id':              id,
    'titulo':          titulo,
    'descricao':       descricao,
    'genero':          genero,
    'status':          status,
    'capa_url':        capaUrl,
    'banner_url':      bannerUrl, // <-- novo
    'autor':           autor,
    'total_capitulos': totalCapitulos,
    'destaque':        destaque ? 1 : 0,
    'criado_em':       criadoEm.toIso8601String(),
    'atualizado_em':   atualizadoEm.toIso8601String(),
  };

  factory Obra.fromSupabase(Map<String, dynamic> map) => Obra(
    id:             map['id'] as String,
    titulo:         map['titulo'] as String,
    descricao:      map['descricao'] as String?,
    genero:         map['genero'] as String?,
    status:         map['status'] as String? ?? 'em_andamento',
    capaUrl:        map['capa_url'] as String?,
    bannerUrl:      map['banner_url'] as String?, // <-- novo
    autor:          map['autor'] as String?,
    totalCapitulos: map['total_capitulos'] as int? ?? 0,
    destaque:       map['destaque'] as bool? ?? false,
    criadoEm:       DateTime.parse(map['criado_em'] as String),
    atualizadoEm:   DateTime.parse(map['atualizado_em'] as String),
  );

  Map<String, dynamic> toSupabase() => {
    'id':              id,
    'titulo':          titulo,
    'descricao':       descricao,
    'genero':          genero,
    'status':          status,
    'capa_url':        capaUrl,
    'banner_url':      bannerUrl, // <-- novo
    'autor':           autor,
    'total_capitulos': totalCapitulos,
    'destaque':        destaque,
    'criado_em':       criadoEm.toIso8601String(),
    'atualizado_em':   atualizadoEm.toIso8601String(),
  };
}