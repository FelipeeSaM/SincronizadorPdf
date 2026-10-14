import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sincronizador_pdf/sync/backend_local_resolver.dart';

void main() {
  final diretorioFalso = Directory('/app-fake');
  const executavelAtualFalso = '/app-fake-instalado/sincronizador_pdf';

  test(
    'retorna dotnet + a variável de ambiente quando o arquivo nela existe',
    () {
      final comando = resolverComandoBackendLocal(
        environment: {variavelCaminhoBackendDll: '/empacotado/backend.dll'},
        diretorioAtual: diretorioFalso,
        caminhoExecutavelAtual: executavelAtualFalso,
        existeArquivo: (caminho) => caminho == '/empacotado/backend.dll',
      );

      expect(comando?.executavel, 'dotnet');
      expect(comando?.argumentos, ['/empacotado/backend.dll']);
      expect(comando?.diretorioExecutavel, '/empacotado');
    },
  );

  test(
    'ignora a variável de ambiente quando o arquivo nela não existe, e tenta o executável empacotado',
    () {
      final comando = resolverComandoBackendLocal(
        environment: {variavelCaminhoBackendDll: '/nao-existe/backend.dll'},
        diretorioAtual: diretorioFalso,
        caminhoExecutavelAtual: executavelAtualFalso,
        existeArquivo: (caminho) => caminho.contains('/app-fake-instalado/backend/'),
      );

      expect(comando?.executavel, contains('/app-fake-instalado/backend/'));
      expect(comando?.executavel, contains('SincronizadorPdf.Backend.Api'));
      expect(comando?.argumentos, isEmpty);
      expect(comando?.diretorioExecutavel, '/app-fake-instalado/backend');
    },
  );

  test(
    'sem variável de ambiente, resolve o executável empacotado ao lado do binário do app (Flatpak/zip)',
    () {
      final comando = resolverComandoBackendLocal(
        environment: const {},
        diretorioAtual: diretorioFalso,
        caminhoExecutavelAtual: executavelAtualFalso,
        existeArquivo: (caminho) => caminho.contains('/app-fake-instalado/backend/'),
      );

      expect(
        comando?.executavel,
        '/app-fake-instalado/backend/SincronizadorPdf.Backend.Api',
      );
      expect(comando?.argumentos, isEmpty);
      expect(comando?.diretorioExecutavel, '/app-fake-instalado/backend');
    },
  );

  test(
    'sem executável empacotado, cai para dotnet + o .dll de dev relativo ao diretório irmão backend/',
    () {
      final comando = resolverComandoBackendLocal(
        environment: const {},
        diretorioAtual: diretorioFalso,
        caminhoExecutavelAtual: executavelAtualFalso,
        existeArquivo: (caminho) => caminho.contains('bin/Debug/net10.0'),
      );

      expect(comando?.executavel, 'dotnet');
      expect(comando?.argumentos, [
        '/app-fake/../backend/src/SincronizadorPdf.Backend.Api/bin/Debug/net10.0/SincronizadorPdf.Backend.Api.dll',
      ]);
      expect(
        comando?.diretorioExecutavel,
        '/app-fake/../backend/src/SincronizadorPdf.Backend.Api/bin/Debug/net10.0',
      );
    },
  );

  test('retorna null quando nenhum dos três caminhos existe', () {
    final comando = resolverComandoBackendLocal(
      environment: const {},
      diretorioAtual: diretorioFalso,
      caminhoExecutavelAtual: executavelAtualFalso,
      existeArquivo: (_) => false,
    );

    expect(comando, isNull);
  });
}
