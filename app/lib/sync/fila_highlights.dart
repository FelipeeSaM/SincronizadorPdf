import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'diretorio_app.dart';
import 'highlight_pendente.dart';

/// Fila Local de Sincronização (ADR-0005) das criações e remoções de
/// Highlight ainda não confirmadas pelo Backend — retidas aqui quando a
/// chamada falha (ex: Backend fora do ar) e reenviadas até confirmação,
/// com o app em foco.
class FilaHighlights {
  FilaHighlights({Future<Directory> Function()? diretorioBase})
    : _diretorioBase = diretorioBase ?? getApplicationSupportDirectory;

  final Future<Directory> Function() _diretorioBase;

  Future<File> _arquivoFila() async {
    final dir = await diretorioComSubpasta(_diretorioBase, 'fila-highlights');
    return File(p.join(dir.path, 'pendentes.json'));
  }

  Future<
    ({
      List<HighlightPendenteCriacao> criacoes,
      List<HighlightPendenteRemocao> remocoes,
    })
  >
  _listarTudo() async {
    final arquivo = await _arquivoFila();
    if (!await arquivo.exists()) {
      return (
        criacoes: <HighlightPendenteCriacao>[],
        remocoes: <HighlightPendenteRemocao>[],
      );
    }

    final conteudo = await arquivo.readAsString();
    if (conteudo.trim().isEmpty) {
      return (
        criacoes: <HighlightPendenteCriacao>[],
        remocoes: <HighlightPendenteRemocao>[],
      );
    }

    final json = jsonDecode(conteudo) as Map<String, dynamic>;
    final criacoes = (json['criacoes'] as List<dynamic>)
        .map(
          (item) =>
              HighlightPendenteCriacao.fromJson(item as Map<String, dynamic>),
        )
        .toList();
    final remocoes = (json['remocoes'] as List<dynamic>)
        .map(
          (item) =>
              HighlightPendenteRemocao.fromJson(item as Map<String, dynamic>),
        )
        .toList();
    return (criacoes: criacoes, remocoes: remocoes);
  }

  Future<void> _salvar(
    List<HighlightPendenteCriacao> criacoes,
    List<HighlightPendenteRemocao> remocoes,
  ) async {
    final arquivo = await _arquivoFila();
    await arquivo.writeAsString(
      jsonEncode({
        'criacoes': criacoes.map((c) => c.toJson()).toList(),
        'remocoes': remocoes.map((r) => r.toJson()).toList(),
      }),
    );
  }

  /// Criações pendentes, de todos os Documentos ou só de [hash] se informado.
  Future<List<HighlightPendenteCriacao>> listarCriacoes([String? hash]) async {
    final tudo = await _listarTudo();
    if (hash == null) return tudo.criacoes;
    return tudo.criacoes.where((c) => c.hash == hash).toList();
  }

  /// Remoções pendentes, de todos os Documentos ou só de [hash] se informado.
  Future<List<HighlightPendenteRemocao>> listarRemocoes([String? hash]) async {
    final tudo = await _listarTudo();
    if (hash == null) return tudo.remocoes;
    return tudo.remocoes.where((r) => r.hash == hash).toList();
  }

  /// Retém [pendente] na fila. Uma criação já enfileirada para o mesmo
  /// Highlight ([HighlightPendenteCriacao.localId]) não gera entrada
  /// duplicada.
  Future<void> enfileirarCriacao(HighlightPendenteCriacao pendente) async {
    final tudo = await _listarTudo();
    if (tudo.criacoes.any((c) => c.localId == pendente.localId)) return;

    await _salvar([...tudo.criacoes, pendente], tudo.remocoes);
  }

  /// Retém [pendente] na fila. Uma remoção já enfileirada para o mesmo
  /// Highlight ([HighlightPendenteRemocao.localId]) não gera entrada
  /// duplicada.
  Future<void> enfileirarRemocao(HighlightPendenteRemocao pendente) async {
    final tudo = await _listarTudo();
    if (tudo.remocoes.any((r) => r.localId == pendente.localId)) return;

    await _salvar(tudo.criacoes, [...tudo.remocoes, pendente]);
  }

  /// Remove da fila a criação pendente de [localId], se houver, e a
  /// retorna — sem nunca ter chegado a chamar o Backend. Usado quando o
  /// Highlight é apagado antes de sua criação ser sincronizada (ver
  /// `HighlightSyncService.apagar`). Retorna `null` se não havia criação
  /// pendente para [localId].
  Future<HighlightPendenteCriacao?> cancelarCriacao(String localId) async {
    final tudo = await _listarTudo();

    HighlightPendenteCriacao? encontrada;
    for (final criacao in tudo.criacoes) {
      if (criacao.localId == localId) {
        encontrada = criacao;
        break;
      }
    }
    if (encontrada == null) return null;

    await _salvar(
      tudo.criacoes.where((c) => c.localId != localId).toList(),
      tudo.remocoes,
    );
    return encontrada;
  }

  Future<void> removerCriacao(String localId) async {
    final tudo = await _listarTudo();
    await _salvar(
      tudo.criacoes.where((c) => c.localId != localId).toList(),
      tudo.remocoes,
    );
  }

  Future<void> removerRemocao(String localId) async {
    final tudo = await _listarTudo();
    await _salvar(
      tudo.criacoes,
      tudo.remocoes.where((r) => r.localId != localId).toList(),
    );
  }
}
