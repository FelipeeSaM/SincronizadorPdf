import 'mdns_backend_browser.dart';

/// Assina a função de busca mDNS usada por [MdnsPairedBackendLocator] —
/// permite substituí-la por um fake nos testes.
typedef BuscarBackendsMdns = Future<List<BackendMdns>> Function({Duration timeout});

/// Localiza, via mDNS, o endereço atual do Backend de Sincronização
/// anunciado pelo Dispositivo já pareado a este — usado ao abrir o app no
/// celular (ver #28) para atualizar o endereço salvo em [BackendUrlStore]
/// sem exigir novo Pareamento quando o Backend muda de endereço (ex: o PC
/// voltou a uma rede diferente da última sincronização).
class MdnsPairedBackendLocator {
  MdnsPairedBackendLocator({BuscarBackendsMdns? buscarBackends})
    : _buscarBackends = buscarBackends ?? MdnsBackendBrowser().buscar;

  final BuscarBackendsMdns _buscarBackends;

  /// Busca por até [timeout] e retorna o `baseUrl` anunciado pelo
  /// Dispositivo [dispositivoPareadoId], ou `null` se nenhum anúncio dele
  /// responder a tempo — a ausência de um Backend na rede local é uma
  /// situação normal (app fora de casa), não um erro, então nunca lança
  /// (ver #28).
  Future<String?> localizar(
    String dispositivoPareadoId, {
    Duration timeout = const Duration(seconds: 2),
  }) async {
    final candidatos = await _buscarBackends(timeout: timeout);
    for (final candidato in candidatos) {
      if (candidato.dispositivoId == dispositivoPareadoId) {
        return candidato.baseUrl;
      }
    }
    return null;
  }
}
