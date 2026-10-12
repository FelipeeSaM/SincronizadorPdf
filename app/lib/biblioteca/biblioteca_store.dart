import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../sync/diretorio_app.dart';
import 'documento_biblioteca.dart';

/// Armazena localmente os Documentos cujo arquivo completo já chegou a
/// este Dispositivo: a Biblioteca (ver CONTEXT.md). Mantém um índice em
/// disco (hash -> metadados) e os bytes de cada Documento, deduplicados
/// por hash — reabrir ou receber de novo o mesmo conteúdo não gera cópias
/// duplicadas.
class BibliotecaStore {
  BibliotecaStore({Future<Directory> Function()? diretorioBase})
    : _diretorioBase = diretorioBase ?? getApplicationSupportDirectory;

  final Future<Directory> Function() _diretorioBase;

  Future<Directory> _diretorioDocumentos() =>
      diretorioComSubpasta(_diretorioBase, 'biblioteca');

  Future<File> _arquivoIndice() async {
    final dir = await _diretorioDocumentos();
    return File(p.join(dir.path, 'indice.json'));
  }

  Future<List<DocumentoBiblioteca>> listar() async {
    final arquivo = await _arquivoIndice();
    if (!await arquivo.exists()) return [];

    final conteudo = await arquivo.readAsString();
    if (conteudo.trim().isEmpty) return [];

    final lista = jsonDecode(conteudo) as List<dynamic>;
    return lista
        .map(
          (item) => DocumentoBiblioteca.fromJson(item as Map<String, dynamic>),
        )
        .toList();
  }

  Future<void> _salvarIndice(List<DocumentoBiblioteca> documentos) async {
    final arquivo = await _arquivoIndice();
    await arquivo.writeAsString(
      jsonEncode(documentos.map((d) => d.toJson()).toList()),
    );
  }

  Future<DocumentoBiblioteca?> obterPorHash(String hash) async {
    final documentos = await listar();
    for (final documento in documentos) {
      if (documento.hash == hash) return documento;
    }
    return null;
  }

  Future<bool> contem(String hash) async => await obterPorHash(hash) != null;

  /// Adiciona [conteudo] à Biblioteca sob [hash], com [nome] de exibição.
  /// Se [hash] já estiver presente, retorna a entrada existente sem
  /// duplicar o arquivo em disco.
  Future<DocumentoBiblioteca> adicionar({
    required String hash,
    required String nome,
    required Uint8List conteudo,
  }) async {
    final existente = await obterPorHash(hash);
    if (existente != null) return existente;

    final dir = await _diretorioDocumentos();
    final caminhoArquivo = p.join(dir.path, '$hash.pdf');
    await File(caminhoArquivo).writeAsBytes(conteudo);

    final documento = DocumentoBiblioteca(
      hash: hash,
      nome: nome,
      caminhoArquivo: caminhoArquivo,
      recebidoEm: DateTime.now(),
    );

    final documentos = await listar();
    documentos.add(documento);
    await _salvarIndice(documentos);

    return documento;
  }

  Future<Uint8List> lerBytes(DocumentoBiblioteca documento) =>
      File(documento.caminhoArquivo).readAsBytes();

  /// Registra que o Documento [hash] foi entregue com sucesso ao Backend
  /// com destino a [destinoDispositivoId], para que reabri-lo não dispare
  /// uma nova tentativa de envio (ver #18). Não tem efeito se [hash] não
  /// estiver na Biblioteca.
  Future<void> marcarEnviadoPara({
    required String hash,
    required String destinoDispositivoId,
  }) async {
    final documentos = await listar();
    final indice = documentos.indexWhere((d) => d.hash == hash);
    if (indice == -1) return;

    final documento = documentos[indice];
    if (documento.enviadoPara.contains(destinoDispositivoId)) return;

    documentos[indice] = documento.comEnviadoPara(destinoDispositivoId);
    await _salvarIndice(documentos);
  }

  /// Remove [hash] da Biblioteca: apaga a entrada do índice e o arquivo
  /// físico em disco (ver #20). Não tem efeito se [hash] não estiver na
  /// Biblioteca.
  ///
  /// Só afeta o estado local deste Dispositivo — não envolve o Backend de
  /// Sincronização nem o Dispositivo de origem. Mantém a Posição de
  /// Leitura e os Highlights locais desse hash intactos, por decisão
  /// deliberada (ver ADR-0006).
  Future<void> remover(String hash) async {
    final documentos = await listar();
    final indice = documentos.indexWhere((d) => d.hash == hash);
    if (indice == -1) return;

    final documento = documentos.removeAt(indice);
    final arquivo = File(documento.caminhoArquivo);
    if (await arquivo.exists()) {
      await arquivo.delete();
    }

    await _salvarIndice(documentos);
  }
}
