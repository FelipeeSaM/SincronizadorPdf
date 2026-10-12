import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:sincronizador_pdf/documento_viewer_screen.dart';

/// Monta um [PdfPageTextRange] de teste com duas linhas de texto ("ab" e
/// "cd", separadas por uma quebra de linha), sem depender do PDFium: as
/// mesmas estruturas de dados que o `pdfrx` usa para descrever texto
/// extraído são classes Dart simples.
///
/// Os fragmentos referenciam um [PdfPageText] "provisório" (mesmo
/// [charRects], sem os fragmentos ainda) em vez do [PdfPageText] final,
/// porque `PdfPageTextFragment.pageText` não pode apontar para um objeto
/// que ainda está sendo construído (os fragmentos são um argumento do
/// construtor do [PdfPageText] final). Isso não afeta o resultado: o
/// cálculo do retângulo de cada fragmento só depende de [charRects], que
/// é o mesmo em ambos.
PdfPageTextRange _selecaoDeDuasLinhas() {
  const fullText = 'ab\ncd';
  const charRects = [
    PdfRect(0, 100, 10, 90), // 'a'
    PdfRect(10, 100, 20, 90), // 'b'
    PdfRect.empty, // '\n'
    PdfRect(0, 80, 10, 70), // 'c'
    PdfRect(10, 80, 20, 70), // 'd'
  ];

  final pageTextProvisorio = PdfPageText(
    pageNumber: 1,
    fullText: fullText,
    charRects: charRects,
    fragments: const [],
  );

  final linha1 = PdfPageTextFragment(
    pageText: pageTextProvisorio,
    index: 0,
    length: 2,
    bounds: const PdfRect(0, 100, 20, 90),
    charRects: charRects.sublist(0, 2),
    direction: PdfTextDirection.ltr,
  );
  final linha2 = PdfPageTextFragment(
    pageText: pageTextProvisorio,
    index: 3,
    length: 2,
    bounds: const PdfRect(0, 80, 20, 70),
    charRects: charRects.sublist(3, 5),
    direction: PdfTextDirection.ltr,
  );

  final pageText = PdfPageText(
    pageNumber: 1,
    fullText: fullText,
    charRects: charRects,
    fragments: [linha1, linha2],
  );

  return pageText.getRangeFromAB(0, fullText.length - 1);
}

void main() {
  group('retangulosDaSelecao', () {
    test(
      'uma seleção cruzando duas linhas gera um retângulo por linha, não um único bloco',
      () {
        final rects = retangulosDaSelecao(_selecaoDeDuasLinhas());

        expect(rects, hasLength(2));
        expect(rects[0].top, 100);
        expect(rects[0].bottom, 90);
        expect(rects[1].top, 80);
        expect(rects[1].bottom, 70);
      },
    );

    test('retângulos cobrem a largura de cada linha selecionada', () {
      final rects = retangulosDaSelecao(_selecaoDeDuasLinhas());

      expect(rects[0].left, 0);
      expect(rects[0].right, 20);
      expect(rects[1].left, 0);
      expect(rects[1].right, 20);
    });
  });

  test('topo da página visível no topo do viewport é 0%', () {
    final percentual = calcularPercentualRolagem(
      pagina: const Rect.fromLTWH(0, 0, 600, 800),
      visivel: const Rect.fromLTWH(0, 0, 600, 400),
    );

    expect(percentual, 0.0);
  });

  test('metade da página rolada para cima do viewport é 50%', () {
    final percentual = calcularPercentualRolagem(
      pagina: const Rect.fromLTWH(0, 0, 600, 800),
      visivel: const Rect.fromLTWH(0, 400, 600, 400),
    );

    expect(percentual, 0.5);
  });

  test('viewport além do fim da página satura em 100%, não extrapola', () {
    final percentual = calcularPercentualRolagem(
      pagina: const Rect.fromLTWH(0, 0, 600, 800),
      visivel: const Rect.fromLTWH(0, 1200, 600, 400),
    );

    expect(percentual, 1.0);
  });

  test(
    'viewport antes do início da página satura em 0%, não fica negativo',
    () {
      final percentual = calcularPercentualRolagem(
        pagina: const Rect.fromLTWH(0, 1000, 600, 800),
        visivel: const Rect.fromLTWH(0, 0, 600, 400),
      );

      expect(percentual, 0.0);
    },
  );

  group('calcularIndicadorRolagem', () {
    test('área visível no topo do Documento posiciona o indicador no topo', () {
      final indicador = calcularIndicadorRolagem(
        alturaTrilho: 1000,
        alturaDocumento: 4000,
        visivel: const Rect.fromLTWH(0, 0, 600, 1000),
        alturaMinima: 32,
      );

      expect(indicador.topo, 0.0);
      expect(indicador.altura, 250.0); // 1000/4000 do trilho de 1000px
    });

    test('área visível na metade do Documento centraliza o indicador', () {
      final indicador = calcularIndicadorRolagem(
        alturaTrilho: 1000,
        alturaDocumento: 4000,
        visivel: const Rect.fromLTWH(0, 1500, 600, 1000),
        alturaMinima: 32,
      );

      expect(indicador.topo, 375.0); // 1500/4000 do trilho de 1000px
      expect(indicador.altura, 250.0);
    });

    test('área visível no fim do Documento encosta o indicador no fim do trilho', () {
      final indicador = calcularIndicadorRolagem(
        alturaTrilho: 1000,
        alturaDocumento: 4000,
        visivel: const Rect.fromLTWH(0, 3000, 600, 1000),
        alturaMinima: 32,
      );

      expect(indicador.topo, 750.0);
      expect(indicador.altura, 250.0);
    });

    test(
      'fração da área visível menor que a altura mínima não encolhe o indicador abaixo dela',
      () {
        final indicador = calcularIndicadorRolagem(
          alturaTrilho: 1000,
          alturaDocumento: 100000,
          visivel: const Rect.fromLTWH(0, 0, 600, 1000),
          alturaMinima: 32,
        );

        expect(indicador.altura, 32.0);
      },
    );

    test(
      'altura mínima do indicador não o empurra para fora do fim do trilho',
      () {
        final indicador = calcularIndicadorRolagem(
          alturaTrilho: 1000,
          alturaDocumento: 100000,
          visivel: const Rect.fromLTWH(0, 99500, 600, 1000),
          alturaMinima: 32,
        );

        expect(indicador.topo, 1000.0 - 32.0);
        expect(indicador.altura, 32.0);
      },
    );

    test(
      'trilho menor que a altura mínima (ex: frame transitório ao '
      'redimensionar a janela) não lança exceção, só satura no trilho',
      () {
        final indicador = calcularIndicadorRolagem(
          alturaTrilho: 10,
          alturaDocumento: 4000,
          visivel: const Rect.fromLTWH(0, 0, 600, 1000),
          alturaMinima: 32,
        );

        expect(indicador.altura, 10.0);
        expect(indicador.topo, 0.0);
      },
    );

    test('Documento sem altura (ainda carregando) não produz indicador', () {
      final indicador = calcularIndicadorRolagem(
        alturaTrilho: 1000,
        alturaDocumento: 0,
        visivel: const Rect.fromLTWH(0, 0, 600, 1000),
        alturaMinima: 32,
      );

      expect(indicador.altura, 0.0);
    });
  });

  group('calcularInicioArrasto', () {
    test(
      'tocar dentro do indicador só guarda o deslocamento, sem pedir navegação',
      () {
        final resultado = calcularInicioArrasto(
          posicaoLocal: 420,
          indicadorTopo: 400,
          indicadorAltura: 100,
          alturaTrilho: 1000,
        );

        expect(resultado.offsetArrasto, 20.0);
        expect(resultado.fracaoParaNavegar, isNull);
      },
    );

    test(
      'tocar exatamente nas bordas do indicador ainda conta como dentro dele',
      () {
        final noTopo = calcularInicioArrasto(
          posicaoLocal: 400,
          indicadorTopo: 400,
          indicadorAltura: 100,
          alturaTrilho: 1000,
        );
        final noFim = calcularInicioArrasto(
          posicaoLocal: 500,
          indicadorTopo: 400,
          indicadorAltura: 100,
          alturaTrilho: 1000,
        );

        expect(noTopo.fracaoParaNavegar, isNull);
        expect(noFim.fracaoParaNavegar, isNull);
      },
    );

    test(
      'tocar fora do indicador pede navegação imediata para a fração tocada e zera o deslocamento',
      () {
        final resultado = calcularInicioArrasto(
          posicaoLocal: 750,
          indicadorTopo: 400,
          indicadorAltura: 100,
          alturaTrilho: 1000,
        );

        expect(resultado.offsetArrasto, 0.0);
        expect(resultado.fracaoParaNavegar, 0.75);
      },
    );
  });
}
