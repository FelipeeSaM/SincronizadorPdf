import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sincronizador_pdf/sync/mdns_backend_browser.dart';
import 'package:sincronizador_pdf/sync/mdns_pairing_client.dart';
import 'package:sincronizador_pdf/sync/pairing_client.dart';

class _PairingClientFake implements PairingClient {
  _PairingClientFake({this.erro, this.resultado});

  final Object? erro;
  final PareamentoConfirmado? resultado;

  final List<String> codigosConfirmados = [];

  @override
  Future<CodigoPareamento> gerarCodigo(String dispositivoId) => throw UnimplementedError();

  @override
  Future<ConsultaStatusPareamento> consultarStatus(String codigo) => throw UnimplementedError();

  @override
  Future<PareamentoConfirmado> confirmarCodigo(String codigo, String dispositivoId) async {
    codigosConfirmados.add(codigo);
    if (erro != null) throw erro!;
    return resultado!;
  }
}

/// Simula um Backend inalcançável que nunca responde nem lança erro (ex:
/// anúncio mDNS desatualizado de um PC desligado, ou firewall descartando
/// pacotes sem RST) — usado para testar que [MdnsPairingClient] não trava
/// esperando por ele indefinidamente.
class _PairingClientNuncaResponde implements PairingClient {
  @override
  Future<CodigoPareamento> gerarCodigo(String dispositivoId) => throw UnimplementedError();

  @override
  Future<ConsultaStatusPareamento> consultarStatus(String codigo) => throw UnimplementedError();

  @override
  Future<PareamentoConfirmado> confirmarCodigo(String codigo, String dispositivoId) =>
      Completer<PareamentoConfirmado>().future;
}

void main() {
  final pareamento = PareamentoConfirmado(outroDispositivoId: 'pc-1', pareadoEm: DateTime(2100));

  MdnsPairingClient criar({
    required List<BackendMdns> candidatos,
    required Map<String, PairingClient> clientesPorBaseUrl,
  }) {
    return MdnsPairingClient(
      buscarBackends: ({Duration timeout = const Duration(seconds: 3)}) async => candidatos,
      criarPairingClient: (baseUrl) => clientesPorBaseUrl[baseUrl]!,
    );
  }

  test('nenhum Backend encontrado lança NenhumBackendMdnsEncontrado', () async {
    final cliente = MdnsPairingClient(
      buscarBackends: ({Duration timeout = const Duration(seconds: 3)}) async => const [],
      criarPairingClient: (_) => throw UnimplementedError('não deveria ser chamado'),
    );

    await expectLater(
      cliente.confirmarCodigo('ABC123', 'celular-1'),
      throwsA(isA<NenhumBackendMdnsEncontrado>()),
    );
  });

  test('único Backend encontrado confirma com sucesso', () async {
    const backend = BackendMdns(baseUrl: 'http://192.168.1.10:5119', dispositivoId: 'pc-1');
    final fake = _PairingClientFake(resultado: pareamento);
    final cliente = criar(candidatos: const [backend], clientesPorBaseUrl: {backend.baseUrl: fake});

    final resultado = await cliente.confirmarCodigo('ABC123', 'celular-1');

    expect(resultado, same(pareamento));
    expect(fake.codigosConfirmados, ['ABC123']);
  });

  test('entre vários Backends, confirma no único que reconhece o código', () async {
    const errado1 = BackendMdns(baseUrl: 'http://192.168.1.10:5119', dispositivoId: 'pc-1');
    const certo = BackendMdns(baseUrl: 'http://192.168.1.11:5119', dispositivoId: 'pc-2');
    const errado2 = BackendMdns(baseUrl: 'http://192.168.1.12:5119', dispositivoId: 'pc-3');

    final cliente = criar(
      candidatos: const [errado1, certo, errado2],
      clientesPorBaseUrl: {
        errado1.baseUrl: _PairingClientFake(erro: const CodigoPareamentoNaoEncontrado()),
        certo.baseUrl: _PairingClientFake(resultado: pareamento),
        errado2.baseUrl: _PairingClientFake(erro: const CodigoPareamentoNaoEncontrado()),
      },
    );

    final resultado = await cliente.confirmarCodigo('ABC123', 'celular-1');

    expect(resultado, same(pareamento));
  });

  test('quando nenhum Backend reconhece o código, lança CodigoPareamentoNaoEncontrado', () async {
    const b1 = BackendMdns(baseUrl: 'http://192.168.1.10:5119', dispositivoId: 'pc-1');
    const b2 = BackendMdns(baseUrl: 'http://192.168.1.11:5119', dispositivoId: 'pc-2');

    final cliente = criar(
      candidatos: const [b1, b2],
      clientesPorBaseUrl: {
        b1.baseUrl: _PairingClientFake(erro: const CodigoPareamentoNaoEncontrado()),
        b2.baseUrl: _PairingClientFake(erro: const CodigoPareamentoNaoEncontrado()),
      },
    );

    await expectLater(
      cliente.confirmarCodigo('ABC123', 'celular-1'),
      throwsA(isA<CodigoPareamentoNaoEncontrado>()),
    );
  });

  test(
    'código expirado/usado no Backend certo tem prioridade sobre NaoEncontrado dos outros',
    () async {
      const errado = BackendMdns(baseUrl: 'http://192.168.1.10:5119', dispositivoId: 'pc-1');
      const certo = BackendMdns(baseUrl: 'http://192.168.1.11:5119', dispositivoId: 'pc-2');

      final cliente = criar(
        candidatos: const [errado, certo],
        clientesPorBaseUrl: {
          errado.baseUrl: _PairingClientFake(erro: const CodigoPareamentoNaoEncontrado()),
          certo.baseUrl: _PairingClientFake(erro: const CodigoPareamentoInvalido()),
        },
      );

      await expectLater(
        cliente.confirmarCodigo('ABC123', 'celular-1'),
        throwsA(isA<CodigoPareamentoInvalido>()),
      );
    },
  );

  test(
    'pareamento com o próprio dispositivo tem prioridade sobre NaoEncontrado dos outros',
    () async {
      const errado = BackendMdns(baseUrl: 'http://192.168.1.10:5119', dispositivoId: 'pc-1');
      const certo = BackendMdns(baseUrl: 'http://192.168.1.11:5119', dispositivoId: 'pc-2');

      final cliente = criar(
        candidatos: const [errado, certo],
        clientesPorBaseUrl: {
          errado.baseUrl: _PairingClientFake(erro: const CodigoPareamentoNaoEncontrado()),
          certo.baseUrl: _PairingClientFake(erro: const CodigoPareamentoDoProprioDispositivo()),
        },
      );

      await expectLater(
        cliente.confirmarCodigo('ABC123', 'celular-1'),
        throwsA(isA<CodigoPareamentoDoProprioDispositivo>()),
      );
    },
  );

  test('falha de rede num Backend tem prioridade sobre NaoEncontrado dos outros', () async {
    const indisponivel = BackendMdns(baseUrl: 'http://192.168.1.10:5119', dispositivoId: 'pc-1');
    const errado = BackendMdns(baseUrl: 'http://192.168.1.11:5119', dispositivoId: 'pc-2');

    final cliente = criar(
      candidatos: const [indisponivel, errado],
      clientesPorBaseUrl: {
        indisponivel.baseUrl: _PairingClientFake(erro: Exception('conexão recusada')),
        errado.baseUrl: _PairingClientFake(erro: const CodigoPareamentoNaoEncontrado()),
      },
    );

    await expectLater(cliente.confirmarCodigo('ABC123', 'celular-1'), throwsException);
  });

  test('um Backend que nunca responde não bloqueia a confirmação nos demais', () async {
    const nuncaResponde = BackendMdns(baseUrl: 'http://192.168.1.10:5119', dispositivoId: 'pc-1');
    const certo = BackendMdns(baseUrl: 'http://192.168.1.11:5119', dispositivoId: 'pc-2');

    final cliente = criar(
      candidatos: const [nuncaResponde, certo],
      clientesPorBaseUrl: {
        nuncaResponde.baseUrl: _PairingClientNuncaResponde(),
        certo.baseUrl: _PairingClientFake(resultado: pareamento),
      },
    );

    final resultado = await cliente
        .confirmarCodigo(
          'ABC123',
          'celular-1',
          timeoutConfirmacao: const Duration(milliseconds: 50),
        )
        .timeout(const Duration(seconds: 2));

    expect(resultado, same(pareamento));
  });

  test('passa o baseUrl de cada candidato à fábrica de PairingClient', () async {
    const backend = BackendMdns(baseUrl: 'http://192.168.1.10:5119', dispositivoId: 'pc-1');
    final fake = _PairingClientFake(resultado: pareamento);
    String? baseUrlRecebida;

    final cliente = MdnsPairingClient(
      buscarBackends: ({Duration timeout = const Duration(seconds: 3)}) async => const [backend],
      criarPairingClient: (baseUrl) {
        baseUrlRecebida = baseUrl;
        return fake;
      },
    );

    await cliente.confirmarCodigo('ABC123', 'celular-1');

    expect(baseUrlRecebida, backend.baseUrl);
  });
}
