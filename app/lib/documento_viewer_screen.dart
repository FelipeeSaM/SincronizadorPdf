import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:pdfrx/pdfrx.dart';

import 'biblioteca/documento_biblioteca.dart';

/// Abre [documento] da Biblioteca no visualizador, empilhando a tela sobre
/// [context].
Future<void> abrirNoVisualizador(
  BuildContext context,
  DocumentoBiblioteca documento,
) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) =>
          DocumentoViewerScreen(caminhoDocumento: documento.caminhoArquivo),
    ),
  );
}

/// Tela de visualização local de um Documento (PDF) escolhido pelo usuário.
///
/// Renderiza o Documento em rolagem contínua por todas as páginas (não
/// paginada), com seleção de texto habilitada quando o Documento tiver
/// camada de texto. Documentos escaneados sem texto continuam abrindo e
/// rolando normalmente, apenas sem seleção disponível.
class DocumentoViewerScreen extends StatelessWidget {
  const DocumentoViewerScreen({super.key, required this.caminhoDocumento});

  /// Caminho local do arquivo PDF a ser exibido.
  final String caminhoDocumento;

  @override
  Widget build(BuildContext context) {
    final nomeDocumento = p.basename(caminhoDocumento);

    return Scaffold(
      appBar: AppBar(title: Text(nomeDocumento)),
      body: PdfViewer.file(
        caminhoDocumento,
        // PdfViewerParams sem `layoutPages` customizado usa o layout padrão
        // do pdfrx, que empilha as páginas verticalmente formando uma única
        // rolagem contínua por todo o Documento (não é um viewer paginado).
        params: const PdfViewerParams(
          textSelectionParams: PdfTextSelectionParams(enabled: true),
        ),
      ),
    );
  }
}
