import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sincronizador_pdf/sync/highlight.dart';
import 'package:sincronizador_pdf/sync/highlight_store.dart';

Highlight _highlight({
  required String localId,
  String? remoteId,
  int page = 1,
}) => Highlight(
  localId: localId,
  remoteId: remoteId,
  page: page,
  rects: const [HighlightRect(left: 0, top: 10, right: 10, bottom: 0)],
  criadoEm: DateTime.utc(2026, 1, 1),
);

void main() {
  late Directory diretorioTemporario;
  late HighlightStore store;

  const hash = 'hash-1';

  setUp(() async {
    diretorioTemporario = await Directory.systemTemp.createTemp(
      'highlight-store-test',
    );
    store = HighlightStore(diretorioBase: () async => diretorioTemporario);
  });

  tearDown(() async {
    if (await diretorioTemporario.exists()) {
      await diretorioTemporario.delete(recursive: true);
    }
  });

  test('lista vazia inicialmente', () async {
    expect(await store.listar(hash), isEmpty);
  });

  test('adicionar retém o Highlight até ser removido', () async {
    await store.adicionar(hash, _highlight(localId: 'h1'));
    expect((await store.listar(hash)).map((h) => h.localId), ['h1']);

    await store.remover(hash, 'h1');
    expect(await store.listar(hash), isEmpty);
  });

  test('definirRemoteId atualiza só o Highlight indicado', () async {
    await store.adicionar(hash, _highlight(localId: 'h1'));
    await store.adicionar(hash, _highlight(localId: 'h2'));

    await store.definirRemoteId(hash, 'h1', 'remoto-1');

    final highlights = await store.listar(hash);
    expect(
      highlights.firstWhere((h) => h.localId == 'h1').remoteId,
      'remoto-1',
    );
    expect(highlights.firstWhere((h) => h.localId == 'h2').remoteId, isNull);
  });

  test('definirRemoteId não falha se o localId não existir mais', () async {
    await store.definirRemoteId(hash, 'desconhecido', 'remoto-x');
    expect(await store.listar(hash), isEmpty);
  });

  test(
    'mesclarComRemotos adiciona Highlights vistos pela primeira vez',
    () async {
      await store.mesclarComRemotos(hash, [
        _highlight(localId: 'remoto-1', remoteId: 'remoto-1'),
      ]);

      final highlights = await store.listar(hash);
      expect(highlights.single.remoteId, 'remoto-1');
    },
  );

  test(
    'mesclarComRemotos remove Highlights sincronizados que não constam mais no Backend',
    () async {
      await store.adicionar(
        hash,
        _highlight(localId: 'h1', remoteId: 'remoto-1'),
      );
      await store.adicionar(
        hash,
        _highlight(localId: 'h2', remoteId: 'remoto-2'),
      );

      // Backend agora só conhece remoto-1: remoto-2 foi apagado em outro Dispositivo.
      await store.mesclarComRemotos(hash, [
        _highlight(localId: 'remoto-1', remoteId: 'remoto-1'),
      ]);

      final restantes = await store.listar(hash);
      expect(restantes.map((h) => h.localId), ['h1']);
    },
  );

  test(
    'mesclarComRemotos preserva criações locais ainda sem remoteId',
    () async {
      await store.adicionar(hash, _highlight(localId: 'pendente'));

      await store.mesclarComRemotos(hash, const []);

      final highlights = await store.listar(hash);
      expect(highlights.single.localId, 'pendente');
      expect(highlights.single.remoteId, isNull);
    },
  );

  test('estado persiste entre instâncias diferentes', () async {
    await store.adicionar(hash, _highlight(localId: 'h1'));

    final outraInstancia = HighlightStore(
      diretorioBase: () async => diretorioTemporario,
    );
    expect((await outraInstancia.listar(hash)).map((h) => h.localId), ['h1']);
  });
}
