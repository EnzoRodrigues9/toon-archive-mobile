class Pagina {
  final String id;
  final String capituloId;
  final int numero;
  final String imagemUrl;
  final String? imagemLocal;

  const Pagina({
    required this.id,
    required this.capituloId,
    required this.numero,
    required this.imagemUrl,
    this.imagemLocal,
  });

  factory Pagina.fromMap(Map<String, dynamic> map) {
    return Pagina(
      id: map['id'],
      capituloId: map['capitulo_id'],
      numero: map['numero'],
      imagemUrl: map['imagem_url'],
      imagemLocal: map['imagem_local'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'capitulo_id': capituloId,
      'numero': numero,
      'imagem_url': imagemUrl,
      'imagem_local': imagemLocal,
    };
  }

  Pagina copyWith({
    String? id,
    String? capituloId,
    int? numero,
    String? imagemUrl,
    String? imagemLocal,
  }) {
    return Pagina(
      id: id ?? this.id,
      capituloId: capituloId ?? this.capituloId,
      numero: numero ?? this.numero,
      imagemUrl: imagemUrl ?? this.imagemUrl,
      imagemLocal: imagemLocal ?? this.imagemLocal,
    );
  }
}