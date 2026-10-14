import 'package:shared_preferences/shared_preferences.dart';

/// Validador de formulário para os campos de endereço do Backend
/// (`PairingScreen`, no PC, e o fallback manual em `HomeScreen`, no
/// celular — ver #28): garante apenas que o campo não foi deixado vazio,
/// sem validar o formato da URL.
String? validarUrlBackendObrigatoria(String? valor) =>
    (valor == null || valor.trim().isEmpty) ? 'Informe o endereço do Backend' : null;

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
