import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// Guarda e recupera o id persistente deste Dispositivo, usado para
/// identificá-lo junto ao Backend de Sincronização durante o Pareamento.
class DeviceIdStore {
  const DeviceIdStore();

  static const _chave = 'device_id';

  Future<String> obterOuCriar() async {
    final prefs = await SharedPreferences.getInstance();
    final existente = prefs.getString(_chave);
    if (existente != null) {
      return existente;
    }

    final novoId = const Uuid().v4();
    await prefs.setString(_chave, novoId);
    return novoId;
  }
}
