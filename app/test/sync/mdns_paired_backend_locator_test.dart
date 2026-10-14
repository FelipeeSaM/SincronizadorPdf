import 'package:flutter_test/flutter_test.dart';
import 'package:sincronizador_pdf/sync/mdns_backend_browser.dart';
import 'package:sincronizador_pdf/sync/mdns_paired_backend_locator.dart';

void main() {
  test('encontra o Backend anunciado pelo Dispositivo pareado', () async {
    const pareado = BackendMdns(baseUrl: 'http://192.168.1.10:5119', dispositivoId: 'pc-1');
    final locator = MdnsPairedBackendLocator(
      buscarBackends: ({Duration timeout = const Duration(seconds: 2)}) async => const [pareado],
    );

    final baseUrl = await locator.localizar('pc-1');

    expect(baseUrl, 'http://192.168.1.10:5119');
  });

  test('ignora anúncios de Backends de outros Dispositivos', () async {
    const outro = BackendMdns(baseUrl: 'http://192.168.1.11:5119', dispositivoId: 'pc-2');
    final locator = MdnsPairedBackendLocator(
      buscarBackends: ({Duration timeout = const Duration(seconds: 2)}) async => const [outro],
    );

    final baseUrl = await locator.localizar('pc-1');

    expect(baseUrl, isNull);
  });

  test('nenhum Backend anunciado retorna null sem lançar erro', () async {
    final locator = MdnsPairedBackendLocator(
      buscarBackends: ({Duration timeout = const Duration(seconds: 2)}) async => const [],
    );

    final baseUrl = await locator.localizar('pc-1');

    expect(baseUrl, isNull);
  });

  test('entre vários anúncios, acha o do Dispositivo pareado', () async {
    const outro = BackendMdns(baseUrl: 'http://192.168.1.11:5119', dispositivoId: 'pc-2');
    const pareado = BackendMdns(baseUrl: 'http://192.168.1.10:5119', dispositivoId: 'pc-1');
    final locator = MdnsPairedBackendLocator(
      buscarBackends: ({Duration timeout = const Duration(seconds: 2)}) async => const [outro, pareado],
    );

    final baseUrl = await locator.localizar('pc-1');

    expect(baseUrl, 'http://192.168.1.10:5119');
  });

  test('passa o timeout informado para a busca mDNS', () async {
    Duration? timeoutRecebido;
    final locator = MdnsPairedBackendLocator(
      buscarBackends: ({Duration timeout = const Duration(seconds: 2)}) async {
        timeoutRecebido = timeout;
        return const [];
      },
    );

    await locator.localizar('pc-1', timeout: const Duration(seconds: 5));

    expect(timeoutRecebido, const Duration(seconds: 5));
  });
}
