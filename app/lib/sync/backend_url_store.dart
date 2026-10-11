import 'package:shared_preferences/shared_preferences.dart';

/// Guarda e recupera o endereço onde o Backend de Sincronização está
/// hospedado — não há descoberta automática, pois é auto-hospedado (ver
/// ADR-0003).
class BackendUrlStore {
  const BackendUrlStore();

  static const _chave = 'backend_base_url';

  Future<String?> obter() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_chave);
  }

  Future<void> salvar(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_chave, url);
  }
}
