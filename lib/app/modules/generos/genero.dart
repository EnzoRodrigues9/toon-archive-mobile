class Genero {
  final String id;
  final String nome;
  final String categoria; // 'demografico' | 'narrativo' | 'tipo'

  const Genero({required this.id, required this.nome, required this.categoria});

  factory Genero.fromMap(Map<String, dynamic> m) => Genero(
        id: m['id'] as String,
        nome: m['nome'] as String,
        categoria: m['categoria'] as String,
      );

  Map<String, dynamic> toMap() => {'id': id, 'nome': nome, 'categoria': categoria};

  factory Genero.fromSupabase(Map<String, dynamic> m) => Genero.fromMap(m);
}