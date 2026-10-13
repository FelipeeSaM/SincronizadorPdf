import 'package:flutter_test/flutter_test.dart';
import 'package:sincronizador_pdf/sync/multicast_lock.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() {
    messenger.setMockMethodCallHandler(canalMulticastLock, null);
  });

  group('MulticastLock.android', () {
    test('adquire o lock nativo antes da ação e libera depois, nessa ordem', () async {
      final chamadas = <String>[];
      messenger.setMockMethodCallHandler(canalMulticastLock, (call) async {
        chamadas.add(call.method);
        return null;
      });

      final lock = MulticastLock.android();
      final resultado = await lock.comLockAtivo(() async {
        chamadas.add('acao');
        return 42;
      });

      expect(resultado, 42);
      expect(chamadas, ['adquirir', 'acao', 'liberar']);
    });

    test('libera o lock nativo mesmo quando a ação lança', () async {
      final chamadas = <String>[];
      messenger.setMockMethodCallHandler(canalMulticastLock, (call) async {
        chamadas.add(call.method);
        return null;
      });

      final lock = MulticastLock.android();

      await expectLater(
        lock.comLockAtivo<void>(() async => throw Exception('busca mDNS falhou')),
        throwsException,
      );

      expect(chamadas, ['adquirir', 'liberar']);
    });
  });

  group('MulticastLock.semLock', () {
    test('executa a ação sem chamar o canal nativo', () async {
      var canalChamado = false;
      messenger.setMockMethodCallHandler(canalMulticastLock, (call) async {
        canalChamado = true;
        return null;
      });

      final lock = MulticastLock.semLock();
      final resultado = await lock.comLockAtivo(() async => 7);

      expect(resultado, 7);
      expect(canalChamado, isFalse);
    });

    test('propaga a exceção da ação sem interferir', () async {
      final lock = MulticastLock.semLock();

      await expectLater(
        lock.comLockAtivo<void>(() async => throw Exception('falhou')),
        throwsException,
      );
    });
  });
}
