import 'dart:io';

import 'package:path/path.dart' as p;

/// Variável de ambiente que aponta direto para o `.dll` do Backend —
/// sobrescreve as outras duas resoluções, para dev/testes manuais (ver
/// #24).
const variavelCaminhoBackendDll = 'SINCRONIZADOR_PDF_BACKEND_DLL';

/// Comando para iniciar o Backend de Sincronização local como processo
/// filho do app desktop (ver [resolverComandoBackendLocal]).
class ComandoBackendLocal {
  const ComandoBackendLocal({
    required this.executavel,
    required this.argumentos,
    required this.diretorioExecutavel,
  });

  final String executavel;
  final List<String> argumentos;

  /// Diretório onde está o `.dll`/executável resolvido — é ali, não num
  /// diretório de dados qualquer, que o ASP.NET Core também espera achar
  /// `appsettings.json` (via `ContentRootPath`, que por padrão segue o
  /// diretório de trabalho do processo). Usar como `workingDirectory` do
  /// processo filho (ver #24, #31).
  final String diretorioExecutavel;
}

/// Resolve como iniciar o Backend de Sincronização local como processo
/// filho do app desktop (ver #24), em ordem de prioridade:
///
/// 1. [variavelCaminhoBackendDll], quando aponta para um `.dll` que existe
///    (dev/override manual) — roda via `dotnet`.
/// 2. O executável self-contained empacotado junto do app (Flatpak/zip, ver
///    #31), numa pasta `backend/` ao lado do binário do app — roda direto,
///    sem precisar de `dotnet` instalado na máquina do usuário.
/// 3. O layout de desenvolvimento, assumindo `app/` e `backend/` como
///    diretórios irmãos no repositório — roda via `dotnet`.
///
/// Retorna `null` se nenhum dos três existir — quem chama decide como lidar
/// com a ausência (hoje, não iniciar o Backend e seguir sem sincronização
/// local).
ComandoBackendLocal? resolverComandoBackendLocal({
  required Map<String, String> environment,
  required Directory diretorioAtual,
  required String caminhoExecutavelAtual,
  bool Function(String caminho) existeArquivo = _existeArquivo,
}) {
  final caminhoVariavel = environment[variavelCaminhoBackendDll];
  if (caminhoVariavel != null && existeArquivo(caminhoVariavel)) {
    return ComandoBackendLocal(
      executavel: 'dotnet',
      argumentos: [caminhoVariavel],
      diretorioExecutavel: p.dirname(caminhoVariavel),
    );
  }

  final caminhoEmpacotado = p.join(
    p.dirname(caminhoExecutavelAtual),
    'backend',
    'SincronizadorPdf.Backend.Api',
  );
  if (existeArquivo(caminhoEmpacotado)) {
    return ComandoBackendLocal(
      executavel: caminhoEmpacotado,
      argumentos: const [],
      diretorioExecutavel: p.dirname(caminhoEmpacotado),
    );
  }

  final caminhoDev = p.join(
    diretorioAtual.path,
    '..',
    'backend',
    'src',
    'SincronizadorPdf.Backend.Api',
    'bin',
    'Debug',
    'net10.0',
    'SincronizadorPdf.Backend.Api.dll',
  );
  if (existeArquivo(caminhoDev)) {
    return ComandoBackendLocal(
      executavel: 'dotnet',
      argumentos: [caminhoDev],
      diretorioExecutavel: p.dirname(caminhoDev),
    );
  }

  return null;
}

bool _existeArquivo(String caminho) => File(caminho).existsSync();
