import 'package:flutter/material.dart';

import '../documento_viewer_screen.dart';
import '../sync/highlight_sync_service.dart';
import '../sync/reading_position_sync_service.dart';
import 'biblioteca_store.dart';
import 'documento_biblioteca.dart';

/// Tela de Biblioteca: lista os Documentos cujo arquivo completo já chegou
/// a este Dispositivo (enviados ou recebidos), permitindo reabri-los ou
/// excluí-los (ver #20).
class BibliotecaScreen extends StatefulWidget {
  const BibliotecaScreen({
    super.key,
    required this.bibliotecaStore,
    this.removerDocumento,
    this.posicaoLeituraSyncService,
    this.highlightSyncService,
  });

  final BibliotecaStore bibliotecaStore;

  /// Remove o Documento de [hash] da Biblioteca ao confirmar a exclusão
  /// (ver #20). `null` usa só [bibliotecaStore.remover] — suficiente
  /// quando não há Backend configurado (ver #8), caso em que também não
  /// há pedido de Transferência pendente para cancelar; com Backend, quem
  /// constrói esta tela deve informar aqui também o cancelamento na Fila
  /// Local (ver `DocumentSyncService.removerDocumento`).
  final Future<void> Function(String hash)? removerDocumento;

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

  Future<bool> _confirmarExclusao(DocumentoBiblioteca documento) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir Documento'),
        content: Text(
          'Excluir "${documento.nome}" da Biblioteca deste Dispositivo? '
          'O Documento original no outro Dispositivo não será afetado. '
          'A única forma de recuperá-lo depois é esse outro Dispositivo '
          'iniciar uma nova Transferência manualmente.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    return confirmado ?? false;
  }

  Future<void> _excluirDocumento(DocumentoBiblioteca documento) async {
    if (!await _confirmarExclusao(documento)) return;

    final remover = widget.removerDocumento ?? widget.bibliotecaStore.remover;
    await remover(documento.hash);

    if (!mounted) return;
    setState(() {
      _documentos = widget.bibliotecaStore.listar();
    });
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
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Excluir',
                  onPressed: () => _excluirDocumento(documento),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
