import 'package:sincronizador_pdf/sync/highlight.dart';
import 'package:sincronizador_pdf/sync/highlight_client.dart';

/// Fake de [HighlightClient] para testar [HighlightSyncService] sem rede
/// real, com um armazenamento em memória equivalente ao do Backend (ver
/// #10), keyed por hash do Documento.
class FakeHighlightClient implements HighlightClient {
  /// Quando `true`, toda chamada lança exceção — simula o Backend fora do
  /// ar (ver ADR-0005).
  bool indisponivel = false;

  final Map<String, Map<String, Highlight>> _porHash = {};
  final List<String> criacoesRecebidas = [];
  final List<String> remocoesRecebidas = [];
  int _proximoId = 1;

  @override
  Future<String> criar({
    required String hash,
    required int page,
    required List<HighlightRect> rects,
    String? trechoTexto,
  }) async {
    if (indisponivel) throw Exception('Backend indisponível');

    final remoteId = 'remoto-${_proximoId++}';
    _porHash.putIfAbsent(hash, () => {})[remoteId] = Highlight(
      localId: remoteId,
      remoteId: remoteId,
      page: page,
      rects: rects,
      trechoTexto: trechoTexto,
      criadoEm: DateTime.utc(2026, 1, 1),
    );
    criacoesRecebidas.add(remoteId);
    return remoteId;
  }

  @override
  Future<List<Highlight>> listar(String hash) async {
    if (indisponivel) throw Exception('Backend indisponível');

    return _porHash[hash]?.values.toList() ?? [];
  }

  @override
  Future<void> apagar(String remoteId) async {
    if (indisponivel) throw Exception('Backend indisponível');

    for (final highlights in _porHash.values) {
      highlights.remove(remoteId);
    }
    remocoesRecebidas.add(remoteId);
  }

  /// Simula um Highlight já persistido no Backend (ex: criado pelo
  /// Dispositivo pareado), sem passar por [criar].
  String semear({
    required String hash,
    required int page,
    List<HighlightRect> rects = const [],
    String? trechoTexto,
  }) {
    final remoteId = 'remoto-${_proximoId++}';
    _porHash.putIfAbsent(hash, () => {})[remoteId] = Highlight(
      localId: remoteId,
      remoteId: remoteId,
      page: page,
      rects: rects,
      trechoTexto: trechoTexto,
      criadoEm: DateTime.utc(2026, 1, 1),
    );
    return remoteId;
  }
}
