import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'diretorio_app.dart';
import 'highlight.dart';

/// Guarda localmente os Highlights conhecidos de cada Documento (ver
/// CONTEXT.md): tanto os já confirmados pelo Backend quanto os criados
/// neste Dispositivo ainda pendentes de sincronização (ADR-0005).
class HighlightStore {
  HighlightStore({Future<Directory> Function()? diretorioBase})
    : _diretorioBase = diretorioBase ?? getApplicationSupportDirectory;

  final Future<Directory> Function() _diretorioBase;

  Future<File> _arquivo(String hash) async {
    final dir = await diretorioComSubpasta(_diretorioBase, 'highlights');
    return File(p.join(dir.path, '$hash.json'));
  }

  Future<List<Highlight>> listar(String hash) async {
    final arquivo = await _arquivo(hash);
    if (!await arquivo.exists()) return [];

    final conteudo = await arquivo.readAsString();
    if (conteudo.trim().isEmpty) return [];

    final lista = jsonDecode(conteudo) as List<dynamic>;
    return lista
        .map((item) => Highlight.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> _salvar(String hash, List<Highlight> highlights) async {
    final arquivo = await _arquivo(hash);
    await arquivo.writeAsString(
      jsonEncode(highlights.map((h) => h.toJson()).toList()),
    );
  }

  Future<void> adicionar(String hash, Highlight highlight) async {
    final highlights = await listar(hash);
    highlights.add(highlight);
    await _salvar(hash, highlights);
  }

  Future<void> remover(String hash, String localId) async {
    final highlights = await listar(hash);
    highlights.removeWhere((h) => h.localId == localId);
    await _salvar(hash, highlights);
  }

  /// Atribui [remoteId] ao Highlight [localId] de [hash], marcando-o como
  /// confirmado pelo Backend. Não faz nada se [localId] não for mais
  /// conhecido localmente (ex: apagado antes da confirmação chegar).
  Future<void> definirRemoteId(
    String hash,
    String localId,
    String remoteId,
  ) async {
    final highlights = await listar(hash);
    final indice = highlights.indexWhere((h) => h.localId == localId);
    if (indice == -1) return;

    highlights[indice] = highlights[indice].comRemoteId(remoteId);
    await _salvar(hash, highlights);
  }

  /// Mescla [remotos] (o estado atual do Backend para [hash]) ao estado
  /// local: adiciona Highlights vistos pela primeira vez (criados no
  /// Dispositivo pareado) e remove os que já haviam sido sincronizados
  /// antes mas não constam mais no Backend (apagados no Dispositivo
  /// pareado). Highlights ainda sem [Highlight.remoteId] (criação local
  /// pendente) nunca são removidos por essa mescla.
  Future<void> mesclarComRemotos(String hash, List<Highlight> remotos) async {
    final locais = await listar(hash);
    final remoteIdsConhecidos = locais
        .map((h) => h.remoteId)
        .whereType<String>()
        .toSet();
    final remoteIdsAtuais = remotos
        .map((h) => h.remoteId)
        .whereType<String>()
        .toSet();

    final mesclados = [
      for (final local in locais)
        if (local.remoteId == null || remoteIdsAtuais.contains(local.remoteId))
          local,
      for (final remoto in remotos)
        if (!remoteIdsConhecidos.contains(remoto.remoteId)) remoto,
    ];

    await _salvar(hash, mesclados);
  }
}
