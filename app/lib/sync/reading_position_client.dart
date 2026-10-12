import 'posicao_leitura.dart';

/// Única interface que a camada de sincronização usa para falar com o
/// Backend de Sincronização a respeito da Posição de Leitura (#8),
/// permitindo testar a reconciliação com um backend fake.
abstract class ReadingPositionClient {
  /// Grava a Posição de Leitura de [hash] definida por [deviceId], com o
  /// timestamp [atualizadoEm] gerado por esse Dispositivo. Retorna a
  /// Posição de Leitura vencedora após a resolução por last-write-wins
  /// (ADR-0005): o próprio valor enviado, se vencer, ou o valor já
  /// existente no Backend, se for mais recente.
  Future<PosicaoLeitura> definir({
    required String hash,
    required String deviceId,
    required int pagina,
    required double percentualRolagem,
    required DateTime atualizadoEm,
  });

  /// Lê a Posição de Leitura mais recente de [hash], ou `null` se o
  /// Backend nunca a recebeu.
  Future<PosicaoLeitura?> obter(String hash);
}
