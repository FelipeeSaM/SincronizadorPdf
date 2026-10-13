import 'dart:async';

import 'package:multicast_dns/multicast_dns.dart';

import 'multicast_lock.dart';

/// Tipo de serviço mDNS/DNS-SD anunciado pelo Backend de Sincronização na
/// rede local (ver `MdnsAnnouncer` no backend, #25).
const tipoServicoMdnsBackend = '_sincpdf._tcp';

/// Um Backend de Sincronização candidato, descoberto via mDNS na rede
/// local (ver #25). [dispositivoId] é o id do PC que o anuncia (TXT
/// record) — usado só para deduplicar anúncios repetidos do mesmo Backend
/// (ex: visto em mais de uma interface de rede), não para decidir qual
/// Backend confirmará um código de Pareamento específico (ver
/// `MdnsPairingClient`, #27).
class BackendMdns {
  const BackendMdns({required this.baseUrl, required this.dispositivoId});

  final String baseUrl;
  final String dispositivoId;

  @override
  bool operator ==(Object other) =>
      other is BackendMdns && other.baseUrl == baseUrl && other.dispositivoId == dispositivoId;

  @override
  int get hashCode => Object.hash(baseUrl, dispositivoId);

  @override
  String toString() => 'BackendMdns(baseUrl: $baseUrl, dispositivoId: $dispositivoId)';
}

/// Extrai o valor da propriedade `dispositivoId` de um TXT record mDNS
/// (ver `MdnsAnnouncer.CreateServiceProfile` no backend). O pacote
/// `multicast_dns` concatena as character-strings do TXT com `\n`, cada
/// uma no formato `chave=valor` — retorna `null` se nenhuma linha tiver
/// essa chave.
String? extrairDispositivoIdDoTxt(String txt) {
  for (final linha in txt.split('\n')) {
    final igual = linha.indexOf('=');
    if (igual == -1) continue;
    if (linha.substring(0, igual) == 'dispositivoId') {
      return linha.substring(igual + 1);
    }
  }
  return null;
}

/// Busca Backends de Sincronização anunciados via mDNS
/// ([tipoServicoMdnsBackend]) na rede local, usada no Pareamento inicial do
/// celular (ver #27) para não precisar do endereço digitado manualmente.
/// Adquire o multicast lock do Android (ver #29) durante a busca.
class MdnsBackendBrowser {
  MdnsBackendBrowser({MulticastLock? multicastLock, MDnsClient Function()? criarClient})
    : _multicastLock = multicastLock ?? MulticastLock.paraPlataforma(),
      _criarClient = criarClient ?? MDnsClient.new;

  final MulticastLock _multicastLock;
  final MDnsClient Function() _criarClient;

  /// Busca por até [timeout] e retorna os Backends distintos encontrados
  /// (deduplicados por dispositivoId) — lista vazia se nenhum responder a
  /// tempo.
  Future<List<BackendMdns>> buscar({Duration timeout = const Duration(seconds: 3)}) {
    return _multicastLock.comLockAtivo(() => _buscarComLockAtivo(timeout));
  }

  Future<List<BackendMdns>> _buscarComLockAtivo(Duration timeout) async {
    final client = _criarClient();
    await client.start();
    try {
      final encontrados = <String, BackendMdns>{};
      try {
        await _coletar(client, timeout, encontrados).timeout(timeout);
      } on TimeoutException {
        // Esgotou o tempo de busca (ver #27) — segue com o que já achou.
      }
      return encontrados.values.toList();
    } finally {
      client.stop();
    }
  }

  Future<void> _coletar(
    MDnsClient client,
    Duration timeout,
    Map<String, BackendMdns> encontrados,
  ) async {
    await for (final ponteiro in client.lookup<PtrResourceRecord>(
      ResourceRecordQuery.serverPointer('$tipoServicoMdnsBackend.local'),
      timeout: timeout,
    )) {
      await for (final servico in client.lookup<SrvResourceRecord>(
        ResourceRecordQuery.service(ponteiro.domainName),
        timeout: timeout,
      )) {
        // TXT (dispositivoId) e endereço IP são buscados em paralelo —
        // nenhum depende do outro, e serializá-los desperdiçaria parte do
        // orçamento fixo de [timeout] da busca (ver #27).
        final resultados = await Future.wait([
          _buscarDispositivoId(client, ponteiro.domainName, timeout),
          _buscarEndereco(client, servico.target, timeout),
        ]);
        final dispositivoId = resultados[0];
        final endereco = resultados[1];
        if (dispositivoId == null || endereco == null) continue;

        encontrados[dispositivoId] = BackendMdns(
          baseUrl: 'http://$endereco:${servico.port}',
          dispositivoId: dispositivoId,
        );
      }
    }
  }

  Future<String?> _buscarDispositivoId(
    MDnsClient client,
    String domainName,
    Duration timeout,
  ) async {
    await for (final txt in client.lookup<TxtResourceRecord>(
      ResourceRecordQuery.text(domainName),
      timeout: timeout,
    )) {
      final dispositivoId = extrairDispositivoIdDoTxt(txt.text);
      if (dispositivoId != null) return dispositivoId;
    }
    return null;
  }

  Future<String?> _buscarEndereco(MDnsClient client, String target, Duration timeout) async {
    await for (final endereco in client.lookup<IPAddressResourceRecord>(
      ResourceRecordQuery.addressIPv4(target),
      timeout: timeout,
    )) {
      return endereco.address.address;
    }
    return null;
  }
}
