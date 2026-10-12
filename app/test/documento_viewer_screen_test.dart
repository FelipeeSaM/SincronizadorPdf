import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sincronizador_pdf/documento_viewer_screen.dart';

void main() {
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

  test('viewport antes do início da página satura em 0%, não fica negativo', () {
    final percentual = calcularPercentualRolagem(
      pagina: const Rect.fromLTWH(0, 1000, 600, 800),
      visivel: const Rect.fromLTWH(0, 0, 600, 400),
    );

    expect(percentual, 0.0);
  });
}
