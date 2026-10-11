import 'dart:io';

import 'package:path/path.dart' as p;

/// Garante que a subpasta [subpasta] dentro do diretório retornado por
/// [base] exista, criando-a se necessário, e a retorna.
Future<Directory> diretorioComSubpasta(
  Future<Directory> Function() base,
  String subpasta,
) async {
  final raiz = await base();
  final dir = Directory(p.join(raiz.path, subpasta));
  if (!await dir.exists()) {
    await dir.create(recursive: true);
  }
  return dir;
}
