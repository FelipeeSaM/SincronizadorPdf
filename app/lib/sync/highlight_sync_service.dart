import 'package:uuid/uuid.dart';

import 'fila_highlights.dart';
import 'highlight.dart';
import 'highlight_client.dart';
import 'highlight_pendente.dart';
import 'highlight_store.dart';

/// Orquestra a criação, remoção e sincronização dos Highlights de um
/// Documento entre este Dispositivo e o Backend de Sincronização (#10),
/// através de [HighlightClient].
///
/// Criação e remoção tentam o Backend imediatamente; se ele estiver
/// inacessível, o evento é retido na [FilaHighlights] (ADR-0005) para
/// reenvio em [sincronizar]. Diferente da Posição de Leitura, a lista de
/// Highlights não é um único valor last-write-wins: [sincronizar] também
/// busca os Highlights atuais do Backend e os mescla aos conhecidos
/// localmente, refletindo tanto criações quanto remoções feitas nesse
/// meio-tempo pelo Dispositivo pareado.
class HighlightSyncService {
  HighlightSyncService({
    required this.client,
    required this.store,
    required this.fila,
  });

  final HighlightClient client;
  final HighlightStore store;
  final FilaHighlights fila;

  /// Cria o Highlight localmente e tenta sincronizá-lo imediatamente com o
  /// Backend; se ele estiver fora do ar, a criação é retida na Fila Local
  /// de Sincronização (ADR-0005) para reenvio em [sincronizar].
  Future<Highlight> criar({
    required String hash,
    required int page,
    required List<HighlightRect> rects,
    String? trechoTexto,
  }) async {
    final highlight = Highlight(
      localId: const Uuid().v4(),
      page: page,
      rects: rects,
      trechoTexto: trechoTexto,
      criadoEm: DateTime.now(),
    );
    await store.adicionar(hash, highlight);

    try {
      final remoteId = await client.criar(
        hash: hash,
        page: page,
        rects: rects,
        trechoTexto: trechoTexto,
      );
      await store.definirRemoteId(hash, highlight.localId, remoteId);
      return highlight.comRemoteId(remoteId);
    } catch (_) {
      await fila.enfileirarCriacao(
        HighlightPendenteCriacao(
          localId: highlight.localId,
          hash: hash,
          page: page,
          rects: rects,
          trechoTexto: trechoTexto,
        ),
      );
      return highlight;
    }
  }

  /// Apaga [highlight] de [hash] localmente e, se ele já tiver sido
  /// aceito pelo Backend, também lá (com retentativa pela Fila Local caso
  /// esteja fora do ar). Se a criação de [highlight] ainda estiver
  /// pendente, apenas a cancela — ela nunca chegou a existir no Backend,
  /// então não há nada para remover lá.
  Future<void> apagar({
    required String hash,
    required Highlight highlight,
  }) async {
    await store.remover(hash, highlight.localId);

    final criacaoPendente = await fila.cancelarCriacao(highlight.localId);
    if (criacaoPendente != null) return;

    final remoteId = highlight.remoteId;
    if (remoteId == null) {
      // Sem remoteId e sem criação pendente: nunca chegou a ser
      // persistido. Nada a fazer além da remoção local já feita acima.
      return;
    }

    try {
      await client.apagar(remoteId);
    } catch (_) {
      await fila.enfileirarRemocao(
        HighlightPendenteRemocao(
          localId: highlight.localId,
          hash: hash,
          remoteId: remoteId,
        ),
      );
    }
  }

  /// Reenvia as criações/remoções de [hash] retidas na Fila Local e busca
  /// os Highlights atuais do Backend, mesclando-os aos conhecidos
  /// localmente. Chamado ao abrir o Documento e periodicamente enquanto a
  /// tela estiver em foco (ADR-0005). Com o Backend fora do ar, mantém
  /// apenas o estado local conhecido, sem falhar.
  Future<List<Highlight>> sincronizar(String hash) async {
    await _reenviarPendentes(hash);

    try {
      final remotos = await client.listar(hash);
      await store.mesclarComRemotos(hash, remotos);
    } catch (_) {
      // Backend indisponível: mantém o estado local conhecido.
    }

    return store.listar(hash);
  }

  Future<void> _reenviarPendentes(String hash) async {
    for (final criacao in await fila.listarCriacoes(hash)) {
      try {
        final remoteId = await client.criar(
          hash: criacao.hash,
          page: criacao.page,
          rects: criacao.rects,
          trechoTexto: criacao.trechoTexto,
        );
        await store.definirRemoteId(hash, criacao.localId, remoteId);
        await fila.removerCriacao(criacao.localId);
      } catch (_) {
        // Backend ainda indisponível: mantém na fila.
      }
    }

    for (final remocao in await fila.listarRemocoes(hash)) {
      try {
        await client.apagar(remocao.remoteId);
        await fila.removerRemocao(remocao.localId);
      } catch (_) {
        // Backend ainda indisponível: mantém na fila.
      }
    }
  }
}
