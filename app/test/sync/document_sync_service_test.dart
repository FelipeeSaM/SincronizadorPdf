import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sincronizador_pdf/biblioteca/biblioteca_store.dart';
import 'package:sincronizador_pdf/sync/document_sync_service.dart';
import 'package:sincronizador_pdf/sync/fila_transferencia.dart';

import 'fake_transfer_client.dart';

void main() {
  late Directory diretorioTemporario;
  late BibliotecaStore biblioteca;
  late FilaTransferencia fila;
  late FakeTransferClient transferClient;
  late DocumentSyncService service;

  const origemId = 'pc-1';
  const destinoId = 'celular-1';

  setUp(() async {
    diretorioTemporario = await Directory.systemTemp.createTemp(
      'document-sync-test',
    );
    biblioteca = BibliotecaStore(
      diretorioBase: () async => diretorioTemporario,
    );
    fila = FilaTransferencia(diretorioBase: () async => diretorioTemporario);
    transferClient = FakeTransferClient();
    service = DocumentSyncService(
      transferClient: transferClient,
      bibliotecaStore: biblioteca,
      filaTransferencia: fila,
      dispositivoId: origemId,
    );
  });

  tearDown(() async {
    if (await diretorioTemporario.exists()) {
      await diretorioTemporario.delete(recursive: true);
    }
  });

  test(
    'abrirDocumento adiciona à Biblioteca e envia ao Dispositivo pareado',
    () async {
      final conteudo = Uint8List.fromList('documento-novo'.codeUnits);

      final documento = await service.abrirDocumento(
        hash: hashDe(conteudo),
        nome: 'artigo.pdf',
        conteudo: conteudo,
        destinoDispositivoId: destinoId,
      );

      expect(await biblioteca.contem(documento.hash), isTrue);
      expect(transferClient.enviosRecebidos, [documento.hash]);
    },
  );

  test(
    'reabrir um Documento já na Biblioteca não dispara nova Transferência',
    () async {
      final conteudo = Uint8List.fromList('documento-repetido'.codeUnits);
      final hash = hashDe(conteudo);

      await service.abrirDocumento(
        hash: hash,
        nome: 'artigo.pdf',
        conteudo: conteudo,
        destinoDispositivoId: destinoId,
      );
      expect(transferClient.enviosRecebidos.length, 1);

      await service.abrirDocumento(
        hash: hash,
        nome: 'artigo.pdf',
        conteudo: conteudo,
        destinoDispositivoId: destinoId,
      );

      expect(transferClient.enviosRecebidos.length, 1);
    },
  );

  test(
    'envio com Backend indisponível retém o pedido na Fila Local e reenvia quando ele volta',
    () async {
      transferClient.indisponivel = true;
      final conteudo = Uint8List.fromList('documento-offline'.codeUnits);
      final hash = hashDe(conteudo);

      await service.abrirDocumento(
        hash: hash,
        nome: 'artigo.pdf',
        conteudo: conteudo,
        destinoDispositivoId: destinoId,
      );

      expect(transferClient.enviosRecebidos, isEmpty);
      expect((await fila.listar()).map((p) => p.hash), [hash]);

      transferClient.indisponivel = false;
      await service.sincronizar();

      expect(transferClient.enviosRecebidos, [hash]);
      expect(await fila.listar(), isEmpty);
    },
  );

  test(
    'envio rejeitado por falta de Pareamento não é retido na Fila Local (não adianta reenviar)',
    () async {
      transferClient.naoPareado = true;
      final conteudo = Uint8List.fromList('documento-sem-pareamento'.codeUnits);
      final hash = hashDe(conteudo);

      await service.abrirDocumento(
        hash: hash,
        nome: 'artigo.pdf',
        conteudo: conteudo,
        destinoDispositivoId: destinoId,
      );

      expect(transferClient.enviosRecebidos, isEmpty);
      expect(await fila.listar(), isEmpty);
      expect(await biblioteca.contem(hash), isTrue);
    },
  );

  test(
    'reenvio que descobre falta de Pareamento remove o pedido da Fila Local em vez de insistir',
    () async {
      transferClient.indisponivel = true;
      final conteudo = Uint8List.fromList(
        'documento-ficara-nao-pareado'.codeUnits,
      );
      final hash = hashDe(conteudo);
      await service.abrirDocumento(
        hash: hash,
        nome: 'artigo.pdf',
        conteudo: conteudo,
        destinoDispositivoId: destinoId,
      );
      expect((await fila.listar()).map((p) => p.hash), [hash]);

      transferClient.indisponivel = false;
      transferClient.naoPareado = true;
      await service.sincronizar();

      expect(transferClient.enviosRecebidos, isEmpty);
      expect(await fila.listar(), isEmpty);
    },
  );

  test(
    'sincronizar baixa Documentos pendentes, adiciona à Biblioteca e confirma recebimento',
    () async {
      final conteudo = Uint8List.fromList('documento-recebido'.codeUnits);
      final hash = hashDe(conteudo);
      transferClient.semearPendente(
        destinoDispositivoId: origemId,
        conteudo: conteudo,
      );

      await service.sincronizar();

      expect(await biblioteca.contem(hash), isTrue);
      expect(transferClient.confirmacoesRecebidas, [hash]);
    },
  );

  test(
    'sincronizar com Backend indisponível não falha e tenta de novo depois',
    () async {
      transferClient.indisponivel = true;

      await service.sincronizar();

      expect(await biblioteca.listar(), isEmpty);

      final conteudo = Uint8List.fromList('documento-adiado'.codeUnits);
      transferClient.semearPendente(
        destinoDispositivoId: origemId,
        conteudo: conteudo,
      );
      transferClient.indisponivel = false;

      await service.sincronizar();

      expect(await biblioteca.contem(hashDe(conteudo)), isTrue);
    },
  );
}
