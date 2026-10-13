import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sincronizador_pdf/pairing/pairing_screen.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('pede o endereço do Backend antes de prosseguir com o Pareamento', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: PairingScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Endereço do Backend de Sincronização'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Continuar'), findsOneWidget);
  });

  testWidgets('com Backend local disponível, pula a tela manual de endereço', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PairingScreen(
          enderecoBackendLocal: Future.value('http://localhost:5119'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Endereço do Backend de Sincronização'), findsNothing);
  });
}
