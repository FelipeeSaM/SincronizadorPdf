import 'package:http/http.dart' as http;

import 'http_pairing_client.dart';
import 'mdns_backend_browser.dart';
import 'pairing_client.dart';

/// Lançado quando a busca mDNS ([MdnsBackendBrowser]) não encontra nenhum
/// Backend de Sincronização na rede dentro do timeout.
class NenhumBackendMdnsEncontrado implements Exception {
  const NenhumBackendMdnsEncontrado();
}

/// Assina a função de busca mDNS usada por [MdnsPairingClient] — permite
/// substituí-la por um fake nos testes (ver #27).
typedef BuscarBackendsMdns = Future<List<BackendMdns>> Function({Duration timeout});

/// Confirma, a partir do celular, um código de Pareamento escaneado sem
/// precisar de endereço manual do Backend (ver #27): busca os Backends
/// anunciados via mDNS na rede local e tenta confirmar o código em cada
/// um. O código escaneado não leva o dispositivoId de quem o gerou (ver
/// [BackendMdns]), mas cada Backend só reconhece os códigos que ele mesmo
/// gerou — então tentar nos candidatos errados não tem efeito colateral
/// além da chamada de rede, e o resultado do Backend certo tem prioridade
/// sobre o "não encontrado" dos demais.
class MdnsPairingClient {
  MdnsPairingClient({BuscarBackendsMdns? buscarBackends, this.criarPairingClient})
    : _buscarBackends = buscarBackends ?? MdnsBackendBrowser().buscar,
      _httpClient = http.Client();

  final BuscarBackendsMdns _buscarBackends;

  /// Permite substituir a criação do [PairingClient] por candidato nos
  /// testes — `null` em produção, quando [_pairingClientPara] usa
  /// [HttpPairingClient] reaproveitando [_httpClient].
  final PairingClient Function(String baseUrl)? criarPairingClient;

  // Reaproveitado por todos os `HttpPairingClient` criados por
  // [_pairingClientPara] (um por candidato mDNS tentado, possivelmente em
  // várias chamadas a [confirmarCodigo] ao longo da vida deste objeto) —
  // sem isso, cada tentativa abriria sua própria conexão HTTP nunca
  // fechada. Só usado quando [criarPairingClient] não foi injetado (ver
  // testes).
  final http.Client _httpClient;

  PairingClient _pairingClientPara(String baseUrl) =>
      criarPairingClient?.call(baseUrl) ?? HttpPairingClient(baseUrl: baseUrl, httpClient: _httpClient);

  /// Libera a conexão HTTP reaproveitada entre as tentativas de
  /// confirmação — chamar quando este cliente não for mais usado (ver
  /// `_PairingScanScreenState.dispose`).
  void dispose() => _httpClient.close();

  /// Busca os Backends na rede (por até [timeoutBusca]) e confirma
  /// [codigo] no que o reconhecer, com até [timeoutConfirmacao] de espera
  /// por candidato — sem esse limite, um único Backend que nunca responde
  /// (ex: anúncio mDNS desatualizado de um PC desligado) travaria a
  /// confirmação inteira, mesmo que o Backend certo já tivesse respondido.
  /// Lança [NenhumBackendMdnsEncontrado] se a busca não achar nenhum
  /// Backend, ou o erro do Backend certo (ver [ErroConfirmacaoPareamento])
  /// se nenhum confirmar com sucesso.
  Future<PareamentoConfirmado> confirmarCodigo(
    String codigo,
    String dispositivoId, {
    Duration timeoutBusca = const Duration(seconds: 3),
    Duration timeoutConfirmacao = const Duration(seconds: 5),
  }) async {
    final candidatos = await _buscarBackends(timeout: timeoutBusca);
    if (candidatos.isEmpty) {
      throw const NenhumBackendMdnsEncontrado();
    }

    final resultados = await Future.wait(
      candidatos.map(
        (candidato) => _tentarConfirmar(candidato, codigo, dispositivoId, timeoutConfirmacao),
      ),
    );

    for (final resultado in resultados) {
      final pareamento = resultado.pareamento;
      if (pareamento != null) return pareamento;
    }
    // Nenhum candidato confirmou: entre os erros, um código inválido/usado
    // ou de auto-Pareamento só pode vir do Backend que de fato reconheceu
    // o código, então tem prioridade sobre o "não encontrado" dos demais.
    for (final resultado in resultados) {
      final erro = resultado.erro;
      if (erro == null) continue;
      if (erro is CodigoPareamentoInvalido || erro is CodigoPareamentoDoProprioDispositivo) {
        throw erro;
      }
    }
    // Sem erro de domínio reconhecível: uma falha de transporte (ex: rede
    // instável, ou o timeout de confirmação acima) é mais informativa para
    // o usuário do que "não encontrado".
    for (final resultado in resultados) {
      final erro = resultado.erro;
      if (erro == null) continue;
      if (erro is! CodigoPareamentoNaoEncontrado) {
        throw erro;
      }
    }
    throw const CodigoPareamentoNaoEncontrado();
  }

  Future<_ResultadoCandidato> _tentarConfirmar(
    BackendMdns candidato,
    String codigo,
    String dispositivoId,
    Duration timeoutConfirmacao,
  ) async {
    try {
      final pareamento = await _pairingClientPara(candidato.baseUrl)
          .confirmarCodigo(codigo, dispositivoId)
          .timeout(timeoutConfirmacao);
      return _ResultadoCandidato(pareamento: pareamento);
    } catch (erro) {
      return _ResultadoCandidato(erro: erro);
    }
  }
}

class _ResultadoCandidato {
  _ResultadoCandidato({this.pareamento, this.erro});

  final PareamentoConfirmado? pareamento;
  final Object? erro;
}
