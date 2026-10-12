import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sincronizador_pdf/sync/fila_highlights.dart';
import 'package:sincronizador_pdf/sync/highlight_pendente.dart';

HighlightPendenteCriacao _criacao({
  required String localId,
  String hash = 'hash-1',
}) => HighlightPendenteCriacao(
  localId: localId,
  hash: hash,
  page: 1,
  rects: const [],
);

HighlightPendenteRemocao _remocao({
  required String localId,
  String hash = 'hash-1',
  String remoteId = 'remoto-1',
}) =>
    HighlightPendenteRemocao(localId: localId, hash: hash, remoteId: remoteId);

void main() {
  late Directory diretorioTemporario;
  late FilaHighlights fila;

  setUp(() async {
    diretorioTemporario = await Directory.systemTemp.createTemp(
      'fila-highlights-test',
    );
    fila = FilaHighlights(diretorioBase: () async => diretorioTemporario);
  });

  tearDown(() async {
    if (await diretorioTemporario.exists()) {
      await diretorioTemporario.delete(recursive: true);
    }
  });

  test('fila vazia inicialmente', () async {
    expect(await fila.listarCriacoes(), isEmpty);
    expect(await fila.listarRemocoes(), isEmpty);
  });

  test('enfileirarCriacao retém até ser removida', () async {
    await fila.enfileirarCriacao(_criacao(localId: 'h1'));
    expect((await fila.listarCriacoes()).map((c) => c.localId), ['h1']);

    await fila.removerCriacao('h1');
    expect(await fila.listarCriacoes(), isEmpty);
  });

  test('enfileirar a mesma criação duas vezes não duplica', () async {
    await fila.enfileirarCriacao(_criacao(localId: 'h1'));
    await fila.enfileirarCriacao(_criacao(localId: 'h1'));

    expect((await fila.listarCriacoes()).length, 1);
  });

  test('enfileirarRemocao retém até ser removida', () async {
    await fila.enfileirarRemocao(_remocao(localId: 'h1'));
    expect((await fila.listarRemocoes()).map((r) => r.localId), ['h1']);

    await fila.removerRemocao('h1');
    expect(await fila.listarRemocoes(), isEmpty);
  });

  test('enfileirar a mesma remoção duas vezes não duplica', () async {
    await fila.enfileirarRemocao(_remocao(localId: 'h1'));
    await fila.enfileirarRemocao(_remocao(localId: 'h1'));

    expect((await fila.listarRemocoes()).length, 1);
  });

  test('cancelarCriacao remove e retorna a criação pendente', () async {
    await fila.enfileirarCriacao(_criacao(localId: 'h1'));

    final cancelada = await fila.cancelarCriacao('h1');

    expect(cancelada?.localId, 'h1');
    expect(await fila.listarCriacoes(), isEmpty);
  });

  test('cancelarCriacao retorna null quando não há criação pendente', () async {
    expect(await fila.cancelarCriacao('inexistente'), isNull);
  });

  test('listarCriacoes e listarRemocoes filtram por hash', () async {
    await fila.enfileirarCriacao(_criacao(localId: 'h1', hash: 'doc-a'));
    await fila.enfileirarCriacao(_criacao(localId: 'h2', hash: 'doc-b'));
    await fila.enfileirarRemocao(_remocao(localId: 'h3', hash: 'doc-a'));

    expect((await fila.listarCriacoes('doc-a')).map((c) => c.localId), ['h1']);
    expect((await fila.listarRemocoes('doc-a')).map((r) => r.localId), ['h3']);
    expect(await fila.listarRemocoes('doc-b'), isEmpty);
  });

  test(
    'criações e remoções persistem juntas entre instâncias diferentes',
    () async {
      await fila.enfileirarCriacao(_criacao(localId: 'h1'));
      await fila.enfileirarRemocao(_remocao(localId: 'h2'));

      final outraInstancia = FilaHighlights(
        diretorioBase: () async => diretorioTemporario,
      );
      expect((await outraInstancia.listarCriacoes()).map((c) => c.localId), [
        'h1',
      ]);
      expect((await outraInstancia.listarRemocoes()).map((r) => r.localId), [
        'h2',
      ]);
    },
  );
}
