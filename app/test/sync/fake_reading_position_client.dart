import 'package:sincronizador_pdf/sync/posicao_leitura.dart';
import 'package:sincronizador_pdf/sync/reading_position_client.dart';

/// Fake de [ReadingPositionClient] para testar [ReadingPositionSyncService]
/// sem rede real, com a mesma resolução por last-write-wins (ADR-0005) do
/// Backend de Sincronização (#8).
class FakeReadingPositionClient implements ReadingPositionClient {
  /// Quando `true`, toda chamada lança exceção — simula o Backend fora do
  /// ar (ver ADR-0005).
  bool indisponivel = false;

  final Map<String, PosicaoLeitura> _remoto = {};
  final List<String> chamadasDefinir = [];

  @override
  Future<PosicaoLeitura> definir({
    required String hash,
    required String deviceId,
    required int pagina,
    required double percentualRolagem,
    required DateTime atualizadoEm,
  }) async {
    if (indisponivel) throw Exception('Backend indisponível');
    chamadasDefinir.add(hash);

    final existente = _remoto[hash];
    if (existente != null && !atualizadoEm.isAfter(existente.atualizadoEm)) {
      return existente;
    }

    final nova = PosicaoLeitura(
      pagina: pagina,
      percentualRolagem: percentualRolagem,
      atualizadoEm: atualizadoEm,
    );
    _remoto[hash] = nova;
    return nova;
  }

  @override
  Future<PosicaoLeitura?> obter(String hash) async {
    if (indisponivel) throw Exception('Backend indisponível');
    return _remoto[hash];
  }

  /// Simula uma Posição de Leitura já definida no Backend pelo Dispositivo
  /// pareado, sem passar por [definir].
  void semear(String hash, PosicaoLeitura posicao) {
    _remoto[hash] = posicao;
  }
}
