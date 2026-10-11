// Smoke test: a tela inicial exibe o botão para abrir um Documento (PDF).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sincronizador_pdf/main.dart';

void main() {
  testWidgets('tela inicial exibe o botao Abrir PDF', (WidgetTester tester) async {
    await tester.pumpWidget(const SincronizadorPdfApp());

    expect(find.text('Abrir PDF'), findsOneWidget);
    expect(find.byIcon(Icons.folder_open), findsOneWidget);
  });
}
