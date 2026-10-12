import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'diretorio_app.dart';
import 'posicao_leitura.dart';

/// Guarda localmente a Posição de Leitura mais recente de cada Documento
/// (ver CONTEXT.md). Diferente da Fila Local de Sincronização, não é um log
/// de eventos a reenviar: é um único valor por Documento, sempre
/// sobrescrito pela gravação mais recente (ADR-0005).
class PosicaoLeituraStore {
  PosicaoLeituraStore({Future<Directory> Function()? diretorioBase})
    : _diretorioBase = diretorioBase ?? getApplicationSupportDirectory;

  final Future<Directory> Function() _diretorioBase;

  Future<File> _arquivo(String hash) async {
    final dir = await diretorioComSubpasta(_diretorioBase, 'posicao-leitura');
    return File(p.join(dir.path, '$hash.json'));
  }

  Future<PosicaoLeitura?> obter(String hash) async {
    final arquivo = await _arquivo(hash);
    if (!await arquivo.exists()) return null;

    final conteudo = await arquivo.readAsString();
    if (conteudo.trim().isEmpty) return null;

    return PosicaoLeitura.fromJson(
      jsonDecode(conteudo) as Map<String, dynamic>,
    );
  }

  Future<void> salvar(String hash, PosicaoLeitura posicao) async {
    final arquivo = await _arquivo(hash);
    await arquivo.writeAsString(jsonEncode(posicao.toJson()));
  }
}
