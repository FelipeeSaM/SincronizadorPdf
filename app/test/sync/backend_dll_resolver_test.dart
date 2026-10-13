import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sincronizador_pdf/sync/backend_dll_resolver.dart';

void main() {
  final diretorioFalso = Directory('/app-fake');

  test(
    'retorna o caminho da variável de ambiente quando o arquivo existe',
    () {
      final caminho = resolverCaminhoBackendDll(
        environment: {variavelCaminhoBackendDll: '/empacotado/backend.dll'},
        diretorioAtual: diretorioFalso,
        existeArquivo: (caminho) => caminho == '/empacotado/backend.dll',
      );

      expect(caminho, '/empacotado/backend.dll');
    },
  );

  test(
    'ignora a variável de ambiente quando o arquivo nela não existe, e cai para o caminho de dev',
    () {
      final caminho = resolverCaminhoBackendDll(
        environment: {variavelCaminhoBackendDll: '/nao-existe/backend.dll'},
        diretorioAtual: diretorioFalso,
        existeArquivo: (caminho) => caminho.contains('bin/Debug/net10.0'),
      );

      expect(caminho, contains('bin/Debug/net10.0'));
      expect(caminho, contains('SincronizadorPdf.Backend.Api.dll'));
    },
  );

  test(
    'sem variável de ambiente, resolve o caminho de dev relativo ao diretório irmão backend/',
    () {
      final caminho = resolverCaminhoBackendDll(
        environment: const {},
        diretorioAtual: diretorioFalso,
        existeArquivo: (caminho) => caminho.contains('bin/Debug/net10.0'),
      );

      expect(
        caminho,
        '/app-fake/../backend/src/SincronizadorPdf.Backend.Api/bin/Debug/net10.0/SincronizadorPdf.Backend.Api.dll',
      );
    },
  );

  test('retorna null quando nenhum caminho existe', () {
    final caminho = resolverCaminhoBackendDll(
      environment: const {},
      diretorioAtual: diretorioFalso,
      existeArquivo: (_) => false,
    );

    expect(caminho, isNull);
  });
}
