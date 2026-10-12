// Smoke test: a tela inicial exibe o botão para abrir um Documento (PDF).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sincronizador_pdf/main.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

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

  testWidgets('botao Tema abre lista com os temas disponiveis', (WidgetTester tester) async {
    await tester.pumpWidget(const SincronizadorPdfApp());
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(OutlinedButton, 'Tema'));
    await tester.pumpAndSettle();

    expect(find.text('Sistema'), findsOneWidget);
    expect(find.text('Claro'), findsOneWidget);
    expect(find.text('Escuro'), findsOneWidget);
  });

  testWidgets(
    'selecionar um tema aplica a mudança imediatamente e persiste para a próxima abertura do app',
    (WidgetTester tester) async {
      await tester.pumpWidget(const SincronizadorPdfApp());
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(OutlinedButton, 'Tema'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Escuro'));
      await tester.pumpAndSettle();

      expect(
        tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
        ThemeMode.dark,
      );

      // Simula reabrir o app: uma nova instância deve carregar o tema salvo.
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(const SincronizadorPdfApp());
      await tester.pumpAndSettle();

      expect(
        tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
        ThemeMode.dark,
      );
    },
  );
}
