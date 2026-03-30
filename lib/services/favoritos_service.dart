import 'package:shared_preferences/shared_preferences.dart';

class FavoritosService {
  /// Retorna a lista de títulos favoritados
  static Future<List<String>> getFavoritos() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList('favoritos') ?? [];
  }

  /// Alterna o status de favorito de um título
  static Future<void> toggleFavorito(String titulo) async {
    final prefs = await SharedPreferences.getInstance();

    List<String> favoritos = prefs.getStringList('favoritos') ?? [];

    if (favoritos.contains(titulo)) {
      favoritos.remove(titulo);
    } else {
      favoritos.add(titulo);
    }

    await prefs.setStringList('favoritos', favoritos);
  }

  /// Verifica se o título está favoritado
  static Future<bool> isFavorito(String titulo) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> favoritos = prefs.getStringList('favoritos') ?? [];
    return favoritos.contains(titulo);
  }
}
