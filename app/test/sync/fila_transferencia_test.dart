import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sincronizador_pdf/sync/fila_transferencia.dart';
import 'package:sincronizador_pdf/sync/pedido_transferencia_pendente.dart';

void main() {
  late Directory diretorioTemporario;
  late FilaTransferencia fila;

  setUp(() async {
    diretorioTemporario = await Directory.systemTemp.createTemp(
      'fila-transferencia-test',
    );
    fila = FilaTransferencia(diretorioBase: () async => diretorioTemporario);
  });

  tearDown(() async {
    if (await diretorioTemporario.exists()) {
      await diretorioTemporario.delete(recursive: true);
    }
  });

  test('fila vazia inicialmente', () async {
    expect(await fila.listar(), isEmpty);
  });

  test('enfileirar retém o pedido até ser removido', () async {
    final pedido = PedidoTransferenciaPendente(
      hash: 'hash-1',
      destinoDispositivoId: 'celular-1',
      criadoEm: DateTime(2026, 1, 1),
    );

    await fila.enfileirar(pedido);
    expect((await fila.listar()).map((p) => p.hash), ['hash-1']);

    await fila.remover(pedido);
    expect(await fila.listar(), isEmpty);
  });

  test('enfileirar o mesmo pedido duas vezes não duplica a entrada', () async {
    final pedido = PedidoTransferenciaPendente(
      hash: 'hash-2',
      destinoDispositivoId: 'celular-1',
      criadoEm: DateTime(2026, 1, 1),
    );

    await fila.enfileirar(pedido);
    await fila.enfileirar(pedido);

    expect((await fila.listar()).length, 1);
  });

  test(
    'o mesmo hash para destinos diferentes gera entradas independentes',
    () async {
      final primeiroPedido = PedidoTransferenciaPendente(
        hash: 'hash-3',
        destinoDispositivoId: 'celular-1',
        criadoEm: DateTime(2026, 1, 1),
      );
      await fila.enfileirar(primeiroPedido);
      await fila.enfileirar(
        PedidoTransferenciaPendente(
          hash: 'hash-3',
          destinoDispositivoId: 'celular-2',
          criadoEm: DateTime(2026, 1, 1),
        ),
      );

      expect((await fila.listar()).length, 2);

      await fila.remover(primeiroPedido);
      final restantes = await fila.listar();
      expect(restantes.length, 1);
      expect(restantes.single.destinoDispositivoId, 'celular-2');
    },
  );

  test('fila persiste entre instâncias diferentes', () async {
    await fila.enfileirar(
      PedidoTransferenciaPendente(
        hash: 'hash-4',
        destinoDispositivoId: 'celular-1',
        criadoEm: DateTime(2026, 1, 1),
      ),
    );

    final outraInstancia = FilaTransferencia(
      diretorioBase: () async => diretorioTemporario,
    );
    expect((await outraInstancia.listar()).map((p) => p.hash), ['hash-4']);
  });
}
