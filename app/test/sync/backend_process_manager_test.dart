import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sincronizador_pdf/sync/backend_process_manager.dart';

import 'fake_process.dart';

void main() {
  late FakeProcess processo;
  late BackendProcessManager manager;
  String? executavelRecebido;
  List<String>? argumentosRecebidos;
  Map<String, String>? environmentRecebido;
  String? workingDirectoryRecebido;

  setUp(() {
    processo = FakeProcess();
    manager = BackendProcessManager(
      executavel: 'dotnet',
      argumentos: const ['backend.dll'],
      environment: const {'SINCRONIZADOR_PDF_LAN_MODE': '1'},
      workingDirectory: '/opt/sincronizador_pdf/backend',
      timeoutPorta: const Duration(milliseconds: 200),
      iniciadorDeProcesso: (
        executavel,
        argumentos, {
        environment,
        workingDirectory,
      }) async {
        executavelRecebido = executavel;
        argumentosRecebidos = argumentos;
        environmentRecebido = environment;
        workingDirectoryRecebido = workingDirectory;
        return processo;
      },
    );
  });

  test(
    'iniciar repassa executável, argumentos, environment e workingDirectory ao iniciador',
    () async {
      final futurePorta = manager.iniciar();
      processo.escreverLinhaDeStdout('SINCRONIZADOR_PDF_PORT=5119');
      await futurePorta;

      expect(executavelRecebido, 'dotnet');
      expect(argumentosRecebidos, ['backend.dll']);
      expect(environmentRecebido, {'SINCRONIZADOR_PDF_LAN_MODE': '1'});
      expect(workingDirectoryRecebido, '/opt/sincronizador_pdf/backend');
    },
  );

  test(
    'iniciar retorna a porta reportada pelo processo no stdout, ignorando linhas de log antes dela',
    () async {
      final futurePorta = manager.iniciar();
      processo.escreverLinhaDeStdout('info: Hosting.Lifetime[14] algo de log');
      processo.escreverLinhaDeStdout('SINCRONIZADOR_PDF_PORT=5120');

      expect(await futurePorta, 5120);
      expect(manager.porta, 5120);
    },
  );

  test(
    'continua recebendo linhas de stdout depois de encontrar a porta, sem erro',
    () async {
      final futurePorta = manager.iniciar();
      processo.escreverLinhaDeStdout('SINCRONIZADOR_PDF_PORT=5121');
      await futurePorta;

      processo.escreverLinhaDeStdout('info: mais log depois da porta');
      await Future<void>.delayed(Duration.zero);

      expect(manager.porta, 5121);
    },
  );

  test(
    'iniciar lança TimeoutException se a porta nunca é reportada',
    () async {
      expect(manager.iniciar(), throwsA(isA<TimeoutException>()));
    },
  );

  test(
    'iniciar lança BackendEncerrouAntesDaPorta se o processo morrer antes de reportar a porta',
    () async {
      final futurePorta = manager.iniciar();
      processo.simularSaidaInesperada(1);

      await expectLater(
        futurePorta,
        throwsA(
          isA<BackendEncerrouAntesDaPorta>().having(
            (erro) => erro.codigoSaida,
            'codigoSaida',
            1,
          ),
        ),
      );
    },
  );

  test(
    'se a porta já foi encontrada, o processo morrer depois não lança erro solto',
    () async {
      final futurePorta = manager.iniciar();
      processo.escreverLinhaDeStdout('SINCRONIZADOR_PDF_PORT=5119');
      await futurePorta;

      processo.simularSaidaInesperada(0);
      await Future<void>.delayed(Duration.zero);

      expect(manager.porta, 5119);
    },
  );

  test('encerrar mata o processo e limpa a porta conhecida', () async {
    final futurePorta = manager.iniciar();
    processo.escreverLinhaDeStdout('SINCRONIZADOR_PDF_PORT=5119');
    await futurePorta;

    manager.encerrar();

    expect(processo.sinaisRecebidos, [ProcessSignal.sigterm]);
    expect(manager.porta, isNull);
  });

  test('encerrar antes de iniciar não lança', () {
    expect(manager.encerrar, returnsNormally);
  });
}
