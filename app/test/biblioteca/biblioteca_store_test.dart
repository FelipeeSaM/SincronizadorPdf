import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sincronizador_pdf/biblioteca/biblioteca_store.dart';

void main() {
  late Directory diretorioTemporario;
  late BibliotecaStore store;

  setUp(() async {
    diretorioTemporario = await Directory.systemTemp.createTemp(
      'biblioteca-test',
    );
    store = BibliotecaStore(diretorioBase: () async => diretorioTemporario);
  });

  tearDown(() async {
    if (await diretorioTemporario.exists()) {
      await diretorioTemporario.delete(recursive: true);
    }
  });

  test('biblioteca vazia inicialmente', () async {
    expect(await store.listar(), isEmpty);
    expect(await store.contem('qualquer-hash'), isFalse);
  });

  test('adicionar grava o Documento e o torna encontrável por hash', () async {
    final conteudo = Uint8List.fromList('conteudo-pdf'.codeUnits);

    final documento = await store.adicionar(
      hash: 'hash-1',
      nome: 'artigo.pdf',
      conteudo: conteudo,
    );

    expect(await store.contem('hash-1'), isTrue);
    expect(await store.lerBytes(documento), conteudo);
    expect((await store.listar()).map((d) => d.hash), ['hash-1']);
  });

  test('adicionar o mesmo hash duas vezes não duplica a entrada', () async {
    final conteudo = Uint8List.fromList('conteudo-repetido'.codeUnits);

    await store.adicionar(
      hash: 'hash-2',
      nome: 'primeiro-nome.pdf',
      conteudo: conteudo,
    );
    final segunda = await store.adicionar(
      hash: 'hash-2',
      nome: 'segundo-nome.pdf',
      conteudo: conteudo,
    );

    final documentos = await store.listar();
    expect(documentos.length, 1);
    expect(segunda.nome, 'primeiro-nome.pdf');
  });

  test('índice persiste entre instâncias diferentes do store', () async {
    await store.adicionar(
      hash: 'hash-3',
      nome: 'persistente.pdf',
      conteudo: Uint8List.fromList('bytes'.codeUnits),
    );

    final outraInstancia = BibliotecaStore(
      diretorioBase: () async => diretorioTemporario,
    );
    final documentos = await outraInstancia.listar();

    expect(documentos.map((d) => d.hash), ['hash-3']);
  });
}
