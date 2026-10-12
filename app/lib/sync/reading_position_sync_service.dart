import 'posicao_leitura.dart';
import 'posicao_leitura_store.dart';
import 'reading_position_client.dart';

/// Orquestra a sincronização da Posição de Leitura de um Documento entre
/// este Dispositivo e o Backend de Sincronização (#8), através de
/// [ReadingPositionClient].
///
/// Diferente da Transferência de Documento, a Posição de Leitura não entra
/// na Fila Local de Sincronização: é um único valor sobrescrito a cada
/// rolagem, não um log de eventos (ADR-0005). Por isso não há pedido
/// pendente a reter — cada chamada a [sincronizar] simplesmente tenta de
/// novo com o valor local atual, que já reflete a rolagem mais recente.
class ReadingPositionSyncService {
  ReadingPositionSyncService({
    required this.client,
    required this.store,
    required this.dispositivoId,
  });

  final ReadingPositionClient client;
  final PosicaoLeituraStore store;
  final String dispositivoId;

  /// Sobrescreve a Posição de Leitura local de [hash] com o timestamp
  /// deste Dispositivo. Chamado a cada rolagem do Documento; não depende
  /// do Backend (ver ADR-0005).
  Future<void> atualizarLocal({
    required String hash,
    required int pagina,
    required double percentualRolagem,
  }) => store.salvar(
    hash,
    PosicaoLeitura(
      pagina: pagina,
      percentualRolagem: percentualRolagem,
      atualizadoEm: DateTime.now(),
    ),
  );

  /// Reconcilia a Posição de Leitura local de [hash] com o Backend: envia
  /// o valor local (se houver) e aplica localmente a Posição de Leitura
  /// vencedora, que pode ser a do próprio Dispositivo pareado se for mais
  /// recente (demo central do app). Com o Backend fora do ar, mantém o
  /// valor local sem falhar — tenta de novo na próxima sincronização.
  ///
  /// Retorna a Posição de Leitura resultante (local se o Backend estiver
  /// inacessível), ou `null` se não houver nenhuma conhecida ainda.
  Future<PosicaoLeitura?> sincronizar(String hash) async {
    final local = await store.obter(hash);

    try {
      if (local == null) {
        final remota = await client.obter(hash);
        if (remota != null) await store.salvar(hash, remota);
        return remota;
      }

      final vencedora = await client.definir(
        hash: hash,
        deviceId: dispositivoId,
        pagina: local.pagina,
        percentualRolagem: local.percentualRolagem,
        atualizadoEm: local.atualizadoEm,
      );

      if (vencedora.atualizadoEm.isAfter(local.atualizadoEm)) {
        await store.salvar(hash, vencedora);
        return vencedora;
      }

      return local;
    } catch (_) {
      return local;
    }
  }
}
