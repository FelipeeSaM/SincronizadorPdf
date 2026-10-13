import 'dart:io';

import 'package:path/path.dart' as p;

/// Variável de ambiente que aponta direto para o `.dll` do Backend —
/// ponto de extensão para empacotamento futuro (ex: Flatpak bundlando um
/// binário publicado), sem precisar mudar este resolvedor.
const variavelCaminhoBackendDll = 'SINCRONIZADOR_PDF_BACKEND_DLL';

/// Resolve o caminho do `.dll` do Backend de Sincronização para iniciá-lo
/// como processo filho do app desktop (ver #24).
///
/// Prioriza [variavelCaminhoBackendDll] quando aponta para um arquivo que
/// existe; sem ela, cai para o layout de desenvolvimento, assumindo `app/`
/// e `backend/` como diretórios irmãos no repositório. Retorna `null` se
/// nenhum dos dois existir — quem chama decide como lidar com a ausência
/// (hoje, não iniciar o Backend e seguir sem sincronização local).
String? resolverCaminhoBackendDll({
  required Map<String, String> environment,
  required Directory diretorioAtual,
  bool Function(String caminho) existeArquivo = _existeArquivo,
}) {
  final caminhoVariavel = environment[variavelCaminhoBackendDll];
  if (caminhoVariavel != null && existeArquivo(caminhoVariavel)) {
    return caminhoVariavel;
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
  return existeArquivo(caminhoDev) ? caminhoDev : null;
}

bool _existeArquivo(String caminho) => File(caminho).existsSync();
