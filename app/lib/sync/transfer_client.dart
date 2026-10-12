import 'dart:typed_data';

/// Resultado de [TransferClient.baixar]: os bytes do Documento e, se
/// propagado pelo Backend (ver #19), o nome original do arquivo na
/// origem.
typedef DocumentoBaixado = ({Uint8List conteudo, String? nome});

/// Erro de domínio ao enviar um Documento, distinto de falhas de
/// rede/transporte.
sealed class ErroEnvioTransferencia implements Exception {
  const ErroEnvioTransferencia();
}

/// Dispositivo de origem e de destino não têm um Pareamento confirmado
/// entre si.
class DispositivosNaoPareados extends ErroEnvioTransferencia {
  const DispositivosNaoPareados();
}

/// Única interface que a camada de sincronização usa para falar com o
/// Backend de Sincronização a respeito de Transferência de Documento,
/// permitindo testar o ciclo de envio/recebimento com um backend fake.
abstract class TransferClient {
  /// Envia os bytes de um Documento de [origemDispositivoId] para
  /// [destinoDispositivoId], com [nome] original propagado ao destino (ver
  /// #19), retornando o hash do conteúdo como identidade do Documento.
  /// Lança [DispositivosNaoPareados] se não houver Pareamento confirmado
  /// entre origem e destino.
  Future<String> enviar({
    required String origemDispositivoId,
    required String destinoDispositivoId,
    required Uint8List conteudo,
    required String nome,
  });

  /// Lista os hashes dos Documentos retidos na fila de relay do Backend à
  /// espera de confirmação de recebimento por [dispositivoId].
  Future<List<String>> listarPendentes(String dispositivoId);

  /// Baixa o Documento identificado por [hash], retido na fila de relay do
  /// Backend para [dispositivoId].
  Future<DocumentoBaixado> baixar({
    required String hash,
    required String dispositivoId,
  });

  /// Confirma o recebimento completo do Documento [hash] por
  /// [dispositivoId], descartando os bytes da fila do Backend.
  Future<void> confirmarRecebimento({
    required String hash,
    required String dispositivoId,
  });
}
