import 'dart:typed_data';

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
  /// [destinoDispositivoId], retornando o hash do conteúdo como identidade
  /// do Documento. Lança [DispositivosNaoPareados] se não houver Pareamento
  /// confirmado entre origem e destino.
  Future<String> enviar({
    required String origemDispositivoId,
    required String destinoDispositivoId,
    required Uint8List conteudo,
  });

  /// Lista os hashes dos Documentos retidos na fila de relay do Backend à
  /// espera de confirmação de recebimento por [dispositivoId].
  Future<List<String>> listarPendentes(String dispositivoId);

  /// Baixa os bytes do Documento identificado por [hash], retido na fila de
  /// relay do Backend para [dispositivoId].
  Future<Uint8List> baixar({
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
