import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import 'biblioteca/biblioteca_screen.dart';
import 'biblioteca/biblioteca_store.dart';
import 'biblioteca/documento_biblioteca.dart';
import 'documento_viewer_screen.dart';
import 'pairing/pairing_screen.dart';
import 'sync/backend_url_store.dart';
import 'sync/device_id_store.dart';
import 'sync/document_sync_service.dart';
import 'sync/fila_highlights.dart';
import 'sync/fila_transferencia.dart';
import 'sync/highlight_store.dart';
import 'sync/highlight_sync_service.dart';
import 'sync/http_highlight_client.dart';
import 'sync/http_reading_position_client.dart';
import 'sync/http_transfer_client.dart';
import 'sync/paired_device_store.dart';
import 'sync/posicao_leitura_store.dart';
import 'sync/reading_position_sync_service.dart';

const _intervaloSincronizacao = Duration(seconds: 5);

/// Tela inicial: permite ao usuário abrir ou soltar um Documento (PDF)
/// local para visualizar e, se houver um Dispositivo pareado, dispara a
/// Transferência dele; também sincroniza em foco os Documentos recebidos
/// do Dispositivo pareado (ver ADR-0005).
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final _bibliotecaStore = BibliotecaStore();
  final _deviceIdStore = const DeviceIdStore();
  final _backendUrlStore = const BackendUrlStore();
  final _pairedDeviceStore = const PairedDeviceStore();

  DocumentSyncService? _syncService;
  ReadingPositionSyncService? _posicaoLeituraSyncService;
  HighlightSyncService? _highlightSyncService;
  String? _dispositivoPareadoId;
  Timer? _timerSincronizacao;
  bool _arrastandoArquivo = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _inicializarSincronizacao();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timerSincronizacao?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // A Fila Local de Sincronização só tenta esvaziar com o app em foco,
    // sem serviço de sincronização em segundo plano (ver ADR-0005).
    if (state == AppLifecycleState.resumed) {
      unawaited(_syncService?.sincronizar());
      _iniciarSincronizacaoPeriodica();
    } else {
      _pararSincronizacaoPeriodica();
    }
  }

  Future<void> _inicializarSincronizacao() async {
    final dispositivoId = await _deviceIdStore.obterOuCriar();
    final backendUrl = await _backendUrlStore.obter();
    final dispositivoPareadoId = await _pairedDeviceStore.obter();

    if (!mounted) return;
    _dispositivoPareadoId = dispositivoPareadoId;

    if (backendUrl == null) {
      // Sem Backend configurado ainda: Documentos abrem e ficam na
      // Biblioteca local, mas não há como tentar Transferência.
      return;
    }

    _syncService = DocumentSyncService(
      transferClient: HttpTransferClient(baseUrl: backendUrl),
      bibliotecaStore: _bibliotecaStore,
      filaTransferencia: FilaTransferencia(),
      dispositivoId: dispositivoId,
    );
    _posicaoLeituraSyncService = ReadingPositionSyncService(
      client: HttpReadingPositionClient(baseUrl: backendUrl),
      store: PosicaoLeituraStore(),
      dispositivoId: dispositivoId,
    );
    _highlightSyncService = HighlightSyncService(
      client: HttpHighlightClient(baseUrl: backendUrl),
      store: HighlightStore(),
      fila: FilaHighlights(),
    );

    unawaited(_syncService!.sincronizar());
    _iniciarSincronizacaoPeriodica();
  }

  void _iniciarSincronizacaoPeriodica() {
    final syncService = _syncService;
    if (syncService == null || _timerSincronizacao != null) return;
    _timerSincronizacao = Timer.periodic(
      _intervaloSincronizacao,
      (_) => syncService.sincronizar(),
    );
  }

  void _pararSincronizacaoPeriodica() {
    _timerSincronizacao?.cancel();
    _timerSincronizacao = null;
  }

  Future<DocumentoBiblioteca> _registrarDocumento(
    Uint8List conteudo,
    String nome,
  ) async {
    final hash = sha256.convert(conteudo).toString();

    final syncService = _syncService;
    if (syncService != null) {
      return syncService.abrirDocumento(
        hash: hash,
        nome: nome,
        conteudo: conteudo,
        destinoDispositivoId: _dispositivoPareadoId,
      );
    }

    return _bibliotecaStore.adicionar(
      hash: hash,
      nome: nome,
      conteudo: conteudo,
    );
  }

  Future<void> _abrirCaminhoDocumento(
    String caminhoDocumento,
    String nome,
  ) async {
    final conteudo = await File(caminhoDocumento).readAsBytes();
    final documento = await _registrarDocumento(conteudo, nome);
    if (!mounted) return;
    await abrirNoVisualizador(
      context,
      documento,
      posicaoLeituraSyncService: _posicaoLeituraSyncService,
      highlightSyncService: _highlightSyncService,
    );
  }

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

    await _abrirCaminhoDocumento(
      caminhoDocumento,
      p.basename(caminhoDocumento),
    );
  }

  Future<void> _aoSoltarArquivos(DropDoneDetails detalhe) async {
    setState(() => _arrastandoArquivo = false);

    for (final arquivo in detalhe.files) {
      if (arquivo.path.toLowerCase().endsWith('.pdf')) {
        await _abrirCaminhoDocumento(arquivo.path, arquivo.name);
        return;
      }
    }
  }

  void _abrirPareamento() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const PairingScreen()));
  }

  void _abrirBiblioteca() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BibliotecaScreen(
          bibliotecaStore: _bibliotecaStore,
          posicaoLeituraSyncService: _posicaoLeituraSyncService,
          highlightSyncService: _highlightSyncService,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sincronizador PDF')),
      body: DropTarget(
        onDragEntered: (_) => setState(() => _arrastandoArquivo = true),
        onDragExited: (_) => setState(() => _arrastandoArquivo = false),
        onDragDone: _aoSoltarArquivos,
        child: ColoredBox(
          color: _arrastandoArquivo
              ? Theme.of(context).colorScheme.primaryContainer
              : Theme.of(context).colorScheme.surface,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_arrastandoArquivo)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 16),
                    child: Text('Solte o PDF aqui'),
                  ),
                ElevatedButton.icon(
                  onPressed: _abrirDocumento,
                  icon: const Icon(Icons.folder_open),
                  label: const Text('Abrir Documento'),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _abrirBiblioteca,
                  icon: const Icon(Icons.library_books),
                  label: const Text('Biblioteca'),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _abrirPareamento,
                  icon: const Icon(Icons.qr_code),
                  label: const Text('Parear Dispositivo'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
