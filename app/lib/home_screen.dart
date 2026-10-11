import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'documento_viewer_screen.dart';

/// Tela inicial: permite ao usuário escolher um Documento (PDF) local para
/// visualizar.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Future<void> _abrirDocumento() async {
    final arquivoEscolhido = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    final caminhoDocumento = arquivoEscolhido?.path;
    if (caminhoDocumento == null) {
      // Usuário cancelou a seleção ou o caminho do arquivo não está
      // disponível na plataforma atual.
      return;
    }

    if (!mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DocumentoViewerScreen(caminhoDocumento: caminhoDocumento),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sincronizador PDF')),
      body: Center(
        child: ElevatedButton.icon(
          onPressed: _abrirDocumento,
          icon: const Icon(Icons.folder_open),
          label: const Text('Abrir Documento'),
        ),
      ),
    );
  }
}
