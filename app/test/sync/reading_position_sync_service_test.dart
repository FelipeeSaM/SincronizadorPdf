import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sincronizador_pdf/sync/posicao_leitura.dart';
import 'package:sincronizador_pdf/sync/posicao_leitura_store.dart';
import 'package:sincronizador_pdf/sync/reading_position_sync_service.dart';

import 'fake_reading_position_client.dart';

void main() {
  late Directory diretorioTemporario;
  late PosicaoLeituraStore store;
  late FakeReadingPositionClient client;
  late ReadingPositionSyncService service;

  const dispositivoId = 'pc-1';
  const hash = 'documento-1';

  setUp(() async {
    diretorioTemporario = await Directory.systemTemp.createTemp(
      'posicao-leitura-test',
    );
    store = PosicaoLeituraStore(diretorioBase: () async => diretorioTemporario);
    client = FakeReadingPositionClient();
    service = ReadingPositionSyncService(
      client: client,
      store: store,
      dispositivoId: dispositivoId,
    );
  });

  tearDown(() async {
    if (await diretorioTemporario.exists()) {
      await diretorioTemporario.delete(recursive: true);
    }
  });

  test(
    'atualizarLocal sobrescreve a Posição de Leitura local sem depender do Backend',
    () async {
      client.indisponivel = true;

      await service.atualizarLocal(
        hash: hash,
        pagina: 3,
        percentualRolagem: 0.25,
      );

      final local = await store.obter(hash);
      expect(local!.pagina, 3);
      expect(local.percentualRolagem, 0.25);
    },
  );

  test(
    'sincronizar envia a Posição de Leitura local mais recente ao Backend',
    () async {
      await service.atualizarLocal(
        hash: hash,
        pagina: 10,
        percentualRolagem: 0.5,
      );

      final resultado = await service.sincronizar(hash);

      expect(resultado!.pagina, 10);
      expect(client.chamadasDefinir, [hash]);
    },
  );

  test(
    'sincronizar aplica a Posição de Leitura do Dispositivo pareado quando ela vence por timestamp',
    () async {
      await service.atualizarLocal(
        hash: hash,
        pagina: 1,
        percentualRolagem: 0.1,
      );
      final maisRecente = PosicaoLeitura(
        pagina: 20,
        percentualRolagem: 0.9,
        atualizadoEm: DateTime.now().add(const Duration(minutes: 5)),
      );
      client.semear(hash, maisRecente);

      final resultado = await service.sincronizar(hash);

      expect(resultado!.pagina, 20);
      final local = await store.obter(hash);
      expect(local!.pagina, 20);
    },
  );

  test(
    'sincronizar sem Posição de Leitura local aplica a definida no Dispositivo pareado (demo central do app)',
    () async {
      final definidaNoOutroDispositivo = PosicaoLeitura(
        pagina: 42,
        percentualRolagem: 0.75,
        atualizadoEm: DateTime.now(),
      );
      client.semear(hash, definidaNoOutroDispositivo);

      final resultado = await service.sincronizar(hash);

      expect(resultado!.pagina, 42);
      expect((await store.obter(hash))!.pagina, 42);
    },
  );

  test(
    'sincronizar sem Posição de Leitura local nem remota retorna null sem falhar',
    () async {
      final resultado = await service.sincronizar(hash);

      expect(resultado, isNull);
    },
  );

  test(
    'sincronizar com Backend fora do ar mantém o valor local e não falha',
    () async {
      await service.atualizarLocal(
        hash: hash,
        pagina: 7,
        percentualRolagem: 0.3,
      );
      client.indisponivel = true;

      final resultado = await service.sincronizar(hash);

      expect(resultado!.pagina, 7);
      expect(client.chamadasDefinir, isEmpty);
    },
  );

  test(
    'ao reconectar, sincronizar reenvia a Posição de Leitura local pendente',
    () async {
      client.indisponivel = true;
      await service.atualizarLocal(
        hash: hash,
        pagina: 15,
        percentualRolagem: 0.6,
      );
      await service.sincronizar(hash);
      expect(client.chamadasDefinir, isEmpty);

      client.indisponivel = false;
      final resultado = await service.sincronizar(hash);

      expect(resultado!.pagina, 15);
      expect(client.chamadasDefinir, [hash]);
    },
  );
}
