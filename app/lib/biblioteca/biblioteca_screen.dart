import 'package:flutter/material.dart';

import '../documento_viewer_screen.dart';
import '../sync/highlight_sync_service.dart';
import '../sync/reading_position_sync_service.dart';
import 'biblioteca_store.dart';
import 'documento_biblioteca.dart';

/// Tela de Biblioteca: lista os Documentos cujo arquivo completo já chegou
/// a este Dispositivo (enviados ou recebidos), permitindo reabri-los.
class BibliotecaScreen extends StatefulWidget {
  const BibliotecaScreen({
    super.key,
    required this.bibliotecaStore,
    this.posicaoLeituraSyncService,
    this.highlightSyncService,
  });

  final BibliotecaStore bibliotecaStore;

  /// Reconciliação da Posição de Leitura com o Backend; `null` quando não
  /// há Backend configurado (ver #8).
  final ReadingPositionSyncService? posicaoLeituraSyncService;

  /// Criação, remoção e sincronização dos Highlights com o Backend;
  /// `null` quando não há Backend configurado (ver #11).
  final HighlightSyncService? highlightSyncService;

  @override
  State<BibliotecaScreen> createState() => _BibliotecaScreenState();
}

class _BibliotecaScreenState extends State<BibliotecaScreen> {
  late Future<List<DocumentoBiblioteca>> _documentos;

  @override
  void initState() {
    super.initState();
    _documentos = widget.bibliotecaStore.listar();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Biblioteca')),
      body: FutureBuilder<List<DocumentoBiblioteca>>(
        future: _documentos,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final documentos = snapshot.data!;
          if (documentos.isEmpty) {
            return const Center(
              child: Text('Nenhum Documento na Biblioteca ainda.'),
            );
          }

          return ListView.builder(
            itemCount: documentos.length,
            itemBuilder: (context, index) {
              final documento = documentos[index];
              return ListTile(
                leading: const Icon(Icons.picture_as_pdf),
                title: Text(documento.nome),
                subtitle: Text('Recebido em ${documento.recebidoEm}'),
                onTap: () => abrirNoVisualizador(
                  context,
                  documento,
                  posicaoLeituraSyncService: widget.posicaoLeituraSyncService,
                  highlightSyncService: widget.highlightSyncService,
                ),
              );
            },
          );
        },
      ),
    );
  }
}
