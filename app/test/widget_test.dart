// Smoke test: a tela inicial exibe o botão para abrir um Documento (PDF).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sincronizador_pdf/main.dart';

void main() {
  testWidgets('tela inicial exibe o botao Abrir Documento', (WidgetTester tester) async {
    await tester.pumpWidget(const SincronizadorPdfApp());

    expect(find.text('Abrir Documento'), findsOneWidget);
    expect(find.byIcon(Icons.folder_open), findsOneWidget);
  });

  testWidgets('tela inicial exibe o botao Parear Dispositivo', (WidgetTester tester) async {
    await tester.pumpWidget(const SincronizadorPdfApp());

    expect(find.text('Parear Dispositivo'), findsOneWidget);
    expect(find.byIcon(Icons.qr_code), findsOneWidget);
  });
}
