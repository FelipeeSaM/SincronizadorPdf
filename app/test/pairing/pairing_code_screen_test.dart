import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sincronizador_pdf/pairing/pairing_code_screen.dart';
import 'package:sincronizador_pdf/sync/pairing_client.dart';

import 'fake_pairing_client.dart';

void main() {
  testWidgets('exibe o QR code e o texto do código gerado', (tester) async {
    final client = FakePairingClient();

    await tester.pumpWidget(MaterialApp(
      home: PairingCodeScreen(pairingClient: client, dispositivoId: 'pc-1'),
    ));
    await tester.pump();

    expect(find.text('ABC123'), findsOneWidget);
    expect(find.textContaining('Escaneie este QR code'), findsOneWidget);

    // Desmonta a tela para cancelar o Timer de consulta periódica antes do
    // fim do teste.
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('mostra pareado com sucesso quando o Backend confirma o código', (tester) async {
    final client = FakePairingClient(
      statusConsultas: const [
        ConsultaStatusPareamento.pendente(),
        ConsultaStatusPareamento.confirmado('celular-1'),
      ],
    );

    await tester.pumpWidget(MaterialApp(
      home: PairingCodeScreen(
        pairingClient: client,
        dispositivoId: 'pc-1',
        intervaloConsulta: const Duration(milliseconds: 10),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 10));
    await tester.pump(const Duration(milliseconds: 10));

    expect(find.text('Dispositivos pareados com sucesso!'), findsOneWidget);
  });

  testWidgets('mostra erro claro e permite gerar novo código quando o código expira', (tester) async {
    final client = FakePairingClient(
      statusConsultas: const [ConsultaStatusPareamento.expirado()],
    );

    await tester.pumpWidget(MaterialApp(
      home: PairingCodeScreen(
        pairingClient: client,
        dispositivoId: 'pc-1',
        intervaloConsulta: const Duration(milliseconds: 10),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 10));

    expect(find.text('O código expirou antes de ser confirmado.'), findsOneWidget);
    expect(find.text('Gerar novo código'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('mostra erro claro, sem crash, quando falha ao gerar o código', (tester) async {
    final client = FakePairingClient(erroAoGerar: Exception('falha de rede'));

    await tester.pumpWidget(MaterialApp(
      home: PairingCodeScreen(pairingClient: client, dispositivoId: 'pc-1'),
    ));
    await tester.pump();

    expect(find.textContaining('Não foi possível gerar'), findsOneWidget);
    expect(find.text('Tentar novamente'), findsOneWidget);
  });
}
