import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sincronizador_pdf/sync/fila_highlights.dart';
import 'package:sincronizador_pdf/sync/highlight_store.dart';
import 'package:sincronizador_pdf/sync/highlight_sync_service.dart';

import 'fake_highlight_client.dart';

void main() {
  late Directory diretorioTemporario;
  late HighlightStore store;
  late FilaHighlights fila;
  late FakeHighlightClient client;
  late HighlightSyncService service;

  const hash = 'hash-1';

  setUp(() async {
    diretorioTemporario = await Directory.systemTemp.createTemp(
      'highlight-sync-test',
    );
    store = HighlightStore(diretorioBase: () async => diretorioTemporario);
    fila = FilaHighlights(diretorioBase: () async => diretorioTemporario);
    client = FakeHighlightClient();
    service = HighlightSyncService(client: client, store: store, fila: fila);
  });

  tearDown(() async {
    if (await diretorioTemporario.exists()) {
      await diretorioTemporario.delete(recursive: true);
    }
  });

  test('criar adiciona localmente e sincroniza com o Backend', () async {
    final highlight = await service.criar(hash: hash, page: 2, rects: const []);

    expect(highlight.remoteId, isNotNull);
    expect(client.criacoesRecebidas, [highlight.remoteId]);

    final locais = await store.listar(hash);
    expect(locais.single.localId, highlight.localId);
    expect(locais.single.remoteId, highlight.remoteId);
  });

  test(
    'criar com Backend indisponível retém a criação na Fila Local e reenvia quando ele volta',
    () async {
      client.indisponivel = true;

      final highlight = await service.criar(
        hash: hash,
        page: 1,
        rects: const [],
      );

      expect(highlight.remoteId, isNull);
      expect(client.criacoesRecebidas, isEmpty);
      expect((await fila.listarCriacoes(hash)).map((c) => c.localId), [
        highlight.localId,
      ]);

      client.indisponivel = false;
      await service.sincronizar(hash);

      expect(client.criacoesRecebidas.length, 1);
      expect(await fila.listarCriacoes(hash), isEmpty);
      expect((await store.listar(hash)).single.remoteId, isNotNull);
    },
  );

  test(
    'apagar um Highlight já sincronizado remove localmente e no Backend',
    () async {
      final highlight = await service.criar(
        hash: hash,
        page: 1,
        rects: const [],
      );

      await service.apagar(hash: hash, highlight: highlight);

      expect(await store.listar(hash), isEmpty);
      expect(client.remocoesRecebidas, [highlight.remoteId]);
    },
  );

  test(
    'apagar com Backend indisponível retém a remoção na Fila Local e reenvia quando ele volta',
    () async {
      final highlight = await service.criar(
        hash: hash,
        page: 1,
        rects: const [],
      );

      client.indisponivel = true;
      await service.apagar(hash: hash, highlight: highlight);

      expect(await store.listar(hash), isEmpty);
      expect(client.remocoesRecebidas, isEmpty);
      expect((await fila.listarRemocoes(hash)).map((r) => r.localId), [
        highlight.localId,
      ]);

      client.indisponivel = false;
      await service.sincronizar(hash);

      expect(client.remocoesRecebidas, [highlight.remoteId]);
      expect(await fila.listarRemocoes(hash), isEmpty);
    },
  );

  test(
    'apagar um Highlight cuja criação ainda está pendente só a cancela, sem chamar o Backend',
    () async {
      client.indisponivel = true;
      final highlight = await service.criar(
        hash: hash,
        page: 1,
        rects: const [],
      );
      expect((await fila.listarCriacoes(hash)).length, 1);

      await service.apagar(hash: hash, highlight: highlight);

      expect(await store.listar(hash), isEmpty);
      expect(await fila.listarCriacoes(hash), isEmpty);
      expect(await fila.listarRemocoes(hash), isEmpty);

      client.indisponivel = false;
      await service.sincronizar(hash);

      expect(client.criacoesRecebidas, isEmpty);
      expect(await store.listar(hash), isEmpty);
    },
  );

  test(
    'sincronizar baixa um Highlight criado no Dispositivo pareado',
    () async {
      final remoteId = client.semear(hash: hash, page: 5);

      final highlights = await service.sincronizar(hash);

      expect(highlights.single.remoteId, remoteId);
      expect((await store.listar(hash)).single.remoteId, remoteId);
    },
  );

  test(
    'sincronizar remove localmente um Highlight apagado no Dispositivo pareado',
    () async {
      final highlight = await service.criar(
        hash: hash,
        page: 1,
        rects: const [],
      );
      expect(await service.sincronizar(hash), hasLength(1));

      // Simula a remoção pelo Dispositivo pareado, direto no Backend fake.
      await client.apagar(highlight.remoteId!);

      final highlights = await service.sincronizar(hash);

      expect(highlights, isEmpty);
      expect(await store.listar(hash), isEmpty);
    },
  );

  test(
    'sincronizar com Backend indisponível não falha e mantém o estado local',
    () async {
      client.indisponivel = true;

      final highlights = await service.sincronizar(hash);

      expect(highlights, isEmpty);
    },
  );
}
