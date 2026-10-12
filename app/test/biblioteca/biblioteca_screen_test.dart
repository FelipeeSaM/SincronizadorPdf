import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sincronizador_pdf/biblioteca/biblioteca_screen.dart';
import 'package:sincronizador_pdf/biblioteca/biblioteca_store.dart';

void main() {
  late Directory diretorioTemporario;
  late BibliotecaStore store;

  setUp(() async {
    diretorioTemporario = await Directory.systemTemp.createTemp(
      'biblioteca-screen-test',
    );
    store = BibliotecaStore(diretorioBase: () async => diretorioTemporario);
    await store.adicionar(
      hash: 'hash-1',
      nome: 'artigo.pdf',
      conteudo: Uint8List.fromList('conteudo'.codeUnits),
    );
  });

  tearDown(() async {
    if (await diretorioTemporario.exists()) {
      await diretorioTemporario.delete(recursive: true);
    }
  });

  // A Biblioteca lê/escreve em disco (dart:io real). O toque no ícone de
  // excluir dispara `_excluirDocumento`, uma função assíncrona cujas
  // chamadas de I/O real só terminam de fato se toda a cadeia — do toque
  // que a inicia até a conclusão do I/O — rodar dentro do mesmo
  // `tester.runAsync`; fora dele, o relógio sintético de `pump` nunca
  // entrega esse resultado de volta ao teste (o Future fica pendente para
  // sempre). Por isso cada interação com o diálogo de exclusão, e cada
  // leitura direta do `store` feita depois de qualquer `runAsync`, está
  // envolta nele aqui.
  Future<void> pumpBibliotecaScreen(WidgetTester tester) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(
        MaterialApp(home: BibliotecaScreen(bibliotecaStore: store)),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await tester.pump();
    });
  }

  Future<void> abrirDialogoDeExclusao(WidgetTester tester) async {
    await tester.runAsync(() async {
      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();
    });
  }

  Future<void> abrirDialogoETocarBotao(
    WidgetTester tester,
    String textoDoBotao,
  ) async {
    await abrirDialogoDeExclusao(tester);
    await tester.runAsync(() async {
      await tester.tap(find.text(textoDoBotao));
      // "Excluir" encadeia duas operações reais de I/O (remover +
      // relistar); alguns ciclos de espera garantem que ambas terminem
      // antes de seguir com as asserções.
      for (var i = 0; i < 5; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await tester.pump();
      }
    });
  }

  Future<bool> contemNaBiblioteca(WidgetTester tester, String hash) async {
    late bool resultado;
    await tester.runAsync(() async {
      resultado = await store.contem(hash);
    });
    return resultado;
  }

  testWidgets('exibe o Documento com um ícone de excluir', (tester) async {
    await pumpBibliotecaScreen(tester);

    expect(find.text('artigo.pdf'), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline), findsOneWidget);
  });

  testWidgets('tocar em excluir pede confirmação antes de remover', (
    tester,
  ) async {
    await pumpBibliotecaScreen(tester);
    await abrirDialogoDeExclusao(tester);

    expect(find.text('Excluir Documento'), findsOneWidget);
    expect(await contemNaBiblioteca(tester, 'hash-1'), isTrue);
  });

  testWidgets('cancelar a confirmação mantém o Documento na lista', (
    tester,
  ) async {
    await pumpBibliotecaScreen(tester);
    await abrirDialogoETocarBotao(tester, 'Cancelar');

    expect(find.text('artigo.pdf'), findsOneWidget);
    expect(await contemNaBiblioteca(tester, 'hash-1'), isTrue);
  });

  testWidgets(
    'confirmar a exclusão remove o Documento da Biblioteca e da lista',
    (tester) async {
      await pumpBibliotecaScreen(tester);
      await abrirDialogoETocarBotao(tester, 'Excluir');

      expect(find.text('artigo.pdf'), findsNothing);
      expect(
        find.text('Nenhum Documento na Biblioteca ainda.'),
        findsOneWidget,
      );
      expect(await contemNaBiblioteca(tester, 'hash-1'), isFalse);
    },
  );
}
