import 'package:shared_preferences/shared_preferences.dart';

/// Guarda e recupera o id do outro Dispositivo pareado a este, definido ao
/// confirmar o Pareamento. Como cada Pareamento vincula exatamente dois
/// Dispositivos, guardar um único id é suficiente.
class PairedDeviceStore {
  const PairedDeviceStore();

  static const _chave = 'paired_device_id';

  Future<String?> obter() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_chave);
  }

  Future<void> salvar(String dispositivoId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_chave, dispositivoId);
  }
}
