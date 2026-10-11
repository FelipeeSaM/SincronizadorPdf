import 'dart:typed_data';

import '../biblioteca/biblioteca_store.dart';
import '../biblioteca/documento_biblioteca.dart';
import 'fila_transferencia.dart';
import 'pedido_transferencia_pendente.dart';
import 'transfer_client.dart';

/// Orquestra o envio e o recebimento de Documentos entre este Dispositivo
/// e o Dispositivo pareado, falando com o Backend de Sincronização através
/// de [TransferClient].
///
/// Envio: [abrirDocumento] tenta entregar o Documento imediatamente; se o
/// Backend estiver inacessível, o pedido é retido na [FilaTransferencia]
/// (ver ADR-0005) para reenvio em [sincronizar]. Recebimento: a cada
/// [sincronizar], consulta os Documentos pendentes endereçados a este
/// Dispositivo, baixa, adiciona à [BibliotecaStore] e confirma o
/// recebimento ao Backend.
class DocumentSyncService {
  DocumentSyncService({
    required this.transferClient,
    required this.bibliotecaStore,
    required this.filaTransferencia,
    required this.dispositivoId,
  });

  final TransferClient transferClient;
  final BibliotecaStore bibliotecaStore;
  final FilaTransferencia filaTransferencia;
  final String dispositivoId;

  /// Processa a abertura de um Documento local identificado por [hash].
  ///
  /// Se o Documento já estiver na Biblioteca (mesmo hash), apenas retorna
  /// a entrada existente, sem disparar nova Transferência. Caso contrário,
  /// adiciona [conteudo] à Biblioteca e, se [destinoDispositivoId] for
  /// informado (Dispositivo pareado conhecido), tenta enviá-lo.
  Future<DocumentoBiblioteca> abrirDocumento({
    required String hash,
    required String nome,
    required Uint8List conteudo,
    String? destinoDispositivoId,
  }) async {
    final existente = await bibliotecaStore.obterPorHash(hash);
    if (existente != null) return existente;

    final documento = await bibliotecaStore.adicionar(
      hash: hash,
      nome: nome,
      conteudo: conteudo,
    );

    if (destinoDispositivoId != null) {
      await _tentarEnviar(
        hash: hash,
        destinoDispositivoId: destinoDispositivoId,
        conteudo: conteudo,
      );
    }

    return documento;
  }

  /// Reenvia pedidos retidos na Fila Local de Sincronização e baixa
  /// Documentos recebidos, adicionando-os à Biblioteca. Chamado ao abrir o
  /// app e periodicamente enquanto ele está em foco (ver ADR-0005).
  Future<void> sincronizar() async {
    await _reenviarPendentes();
    await _receberPendentes();
  }

  Future<void> _tentarEnviar({
    required String hash,
    required String destinoDispositivoId,
    required Uint8List conteudo,
  }) async {
    try {
      await transferClient.enviar(
        origemDispositivoId: dispositivoId,
        destinoDispositivoId: destinoDispositivoId,
        conteudo: conteudo,
      );
    } on ErroEnvioTransferencia {
      // Erro de domínio (ex.: Dispositivos não pareados): reenviar não vai
      // resolver, então não retém na Fila Local de Sincronização.
    } catch (_) {
      await filaTransferencia.enfileirar(
        PedidoTransferenciaPendente(
          hash: hash,
          destinoDispositivoId: destinoDispositivoId,
          criadoEm: DateTime.now(),
        ),
      );
    }
  }

  Future<void> _reenviarPendentes() async {
    for (final pedido in await filaTransferencia.listar()) {
      final documento = await bibliotecaStore.obterPorHash(pedido.hash);
      if (documento == null) {
        // Documento não existe mais localmente: nada para reenviar.
        await filaTransferencia.remover(pedido);
        continue;
      }

      try {
        final conteudo = await bibliotecaStore.lerBytes(documento);
        await transferClient.enviar(
          origemDispositivoId: dispositivoId,
          destinoDispositivoId: pedido.destinoDispositivoId,
          conteudo: conteudo,
        );
        await filaTransferencia.remover(pedido);
      } on ErroEnvioTransferencia {
        // Erro de domínio permanente: reenviar não vai resolver, então
        // desiste e remove da fila em vez de tentar para sempre.
        await filaTransferencia.remover(pedido);
      } catch (_) {
        // Backend ainda inacessível: mantém na fila para a próxima tentativa.
      }
    }
  }

  Future<void> _receberPendentes() async {
    List<String> hashes;
    try {
      hashes = await transferClient.listarPendentes(dispositivoId);
    } catch (_) {
      return;
    }

    for (final hash in hashes) {
      if (await bibliotecaStore.contem(hash)) {
        // Já está na Biblioteca (ex: confirmação anterior falhou): apenas
        // destrava a fila do Backend confirmando de novo.
        await _confirmarRecebimento(hash);
        continue;
      }

      try {
        final conteudo = await transferClient.baixar(
          hash: hash,
          dispositivoId: dispositivoId,
        );
        await bibliotecaStore.adicionar(
          hash: hash,
          nome: _nomeParaDocumentoRecebido(hash),
          conteudo: conteudo,
        );
        await _confirmarRecebimento(hash);
      } catch (_) {
        // Tenta de novo na próxima sincronização.
      }
    }
  }

  Future<void> _confirmarRecebimento(String hash) async {
    try {
      await transferClient.confirmarRecebimento(
        hash: hash,
        dispositivoId: dispositivoId,
      );
    } catch (_) {
      // Tenta confirmar de novo na próxima sincronização.
    }
  }

  String _nomeParaDocumentoRecebido(String hash) =>
      'Documento ${hash.substring(0, 8)}.pdf';
}
