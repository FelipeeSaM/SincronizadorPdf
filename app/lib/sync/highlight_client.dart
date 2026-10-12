import 'highlight.dart';

/// Única interface que a camada de sincronização usa para falar com o
/// Backend de Sincronização a respeito de Highlights (#10), permitindo
/// testar a sincronização com um backend fake.
abstract class HighlightClient {
  /// Cria o Highlight de [hash] na página [page], com os retângulos
  /// [rects] que compõem seu desenho (ADR-0001) e o texto selecionado
  /// opcional [trechoTexto]. Retorna o id atribuído pelo Backend.
  Future<String> criar({
    required String hash,
    required int page,
    required List<HighlightRect> rects,
    String? trechoTexto,
  });

  /// Lista os Highlights atualmente persistidos pelo Backend para [hash].
  Future<List<Highlight>> listar(String hash);

  /// Apaga do Backend o Highlight [remoteId].
  Future<void> apagar(String remoteId);
}
