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
import 'sync/mdns_paired_backend_locator.dart';
import 'sync/paired_device_store.dart';
import 'sync/posicao_leitura_store.dart';
import 'sync/reading_position_sync_service.dart';

const _intervaloSincronizacao = Duration(seconds: 5);

String _nomeTema(ThemeMode tema) => switch (tema) {
  ThemeMode.system => 'Sistema',
  ThemeMode.light => 'Claro',
  ThemeMode.dark => 'Escuro',
};

/// Tela inicial: permite ao usuário abrir ou soltar um Documento (PDF)
/// local para visualizar e, se houver um Dispositivo pareado, dispara a
/// Transferência dele; também sincroniza em foco os Documentos recebidos
/// do Dispositivo pareado (ver ADR-0005).
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.temaAtual,
    required this.onSelecionarTema,
    this.enderecoBackendLocal,
    this.mdnsPairedBackendLocator,
  });

  final ThemeMode temaAtual;
  final ValueChanged<ThemeMode> onSelecionarTema;

  /// `http://localhost:<porta>` do Backend local (ver #24), ou `null` em
  /// plataformas sem Backend local ou se ele não iniciou — nesse caso cai de
  /// volta no endereço salvo manualmente via [BackendUrlStore] (ver #26).
  final Future<String?>? enderecoBackendLocal;

  /// Permite injetar um fake nos testes — `null` em produção, quando
  /// [_HomeScreenState] usa a implementação real.
  final MdnsPairedBackendLocator? mdnsPairedBackendLocator;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final _bibliotecaStore = BibliotecaStore();
  final _deviceIdStore = const DeviceIdStore();
  final _backendUrlStore = const BackendUrlStore();
  final _pairedDeviceStore = const PairedDeviceStore();
  late final _mdnsPairedBackendLocator =
      widget.mdnsPairedBackendLocator ?? MdnsPairedBackendLocator();

  static bool get _ehDispositivoMovel => Platform.isAndroid || Platform.isIOS;

  DocumentSyncService? _syncService;
  ReadingPositionSyncService? _posicaoLeituraSyncService;
  HighlightSyncService? _highlightSyncService;
  String? _dispositivoId;
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
      unawaited(_aoRetomarFoco());
    } else {
      _pararSincronizacaoPeriodica();
    }
  }

  /// No celular, repete a descoberta mDNS a cada vez que o app volta ao
  /// foco (ver #28): é exatamente esse o momento do cenário de uso — o
  /// usuário sai de casa com o app em segundo plano e volta depois, sem
  /// reabri-lo do zero — em que o endereço do Backend pode ter mudado (ex:
  /// o PC entrou numa rede diferente) desde a última sincronização.
  ///
  /// `_iniciarSincronizacaoPeriodica` só é chamado ao final, depois da
  /// busca mDNS (em vez de direto em `didChangeAppLifecycleState`): como
  /// ela é assíncrona, chamá-lo antes dela terminar veria `_syncService`
  /// ainda `null` sempre que o app reabre sem Backend configurado, e o
  /// timer nunca seria iniciado nessa sessão em foco.
  Future<void> _aoRetomarFoco() async {
    final dispositivoId = _dispositivoId;
    final dispositivoPareadoId = _dispositivoPareadoId;
    if (_ehDispositivoMovel && dispositivoId != null && dispositivoPareadoId != null) {
      final backendUrl = await _descobrirBackendViaMdns(dispositivoPareadoId);
      if (backendUrl != null) {
        _configurarServicosSincronizacao(backendUrl, dispositivoId);
      }
    }
    await _syncService?.sincronizar();
    _iniciarSincronizacaoPeriodica();
  }

  Future<void> _inicializarSincronizacao() async {
    // Disparados antes de aguardar o endereço do Backend — que, no PC, pode
    // demorar até o timeout do `BackendProcessManager` (10s) se o Backend
    // local estiver lento para subir (ver #24) — para não atrasar também
    // essas duas leituras locais independentes.
    final dispositivoIdFuture = _deviceIdStore.obterOuCriar();
    final dispositivoPareadoIdFuture = _pairedDeviceStore.obter();

    final dispositivoId = await dispositivoIdFuture;
    final enderecoBackendLocal = await widget.enderecoBackendLocal;
    final dispositivoPareadoId = await dispositivoPareadoIdFuture;

    if (!mounted) return;
    _dispositivoId = dispositivoId;
    _dispositivoPareadoId = dispositivoPareadoId;

    // No celular, a descoberta mDNS roda a cada abertura do app (ver #28)
    // e tem prioridade sobre o endereço salvo da última vez — o Backend
    // pode ter mudado de endereço desde então (ex: o PC voltou a uma rede
    // diferente) — mas só faz sentido com um Dispositivo já pareado, já
    // que ela filtra pelo `dispositivoId` dele.
    var backendUrl = enderecoBackendLocal;
    if (backendUrl == null && _ehDispositivoMovel && dispositivoPareadoId != null) {
      backendUrl = await _descobrirBackendViaMdns(dispositivoPareadoId);
    }
    backendUrl ??= await _backendUrlStore.obter();

    if (!mounted) return;

    if (backendUrl == null) {
      // Sem Backend configurado ainda: Documentos abrem e ficam na
      // Biblioteca local, mas não há como tentar Transferência.
      return;
    }

    _configurarServicosSincronizacao(backendUrl, dispositivoId);

    unawaited(_syncService!.sincronizar());
    _iniciarSincronizacaoPeriodica();
  }

  /// Busca o Backend anunciado via mDNS pelo Dispositivo pareado
  /// [dispositivoPareadoId] e, se encontrado, atualiza o endereço salvo em
  /// [_backendUrlStore] (ver #28). Nunca lança: se a busca não encontrar
  /// nada (app fora da rede do Backend) ou falhar por algum outro motivo
  /// (ex: multicast bloqueado), segue offline normalmente, sem bloquear a
  /// abertura do app — a tela manual de URL continua disponível como
  /// fallback explícito em [PairingScreen].
  Future<String?> _descobrirBackendViaMdns(String dispositivoPareadoId) async {
    try {
      final backendUrl = await _mdnsPairedBackendLocator.localizar(dispositivoPareadoId);
      if (backendUrl != null) {
        await _backendUrlStore.salvar(backendUrl);
      }
      return backendUrl;
    } catch (_) {
      return null;
    }
  }

  void _configurarServicosSincronizacao(String backendUrl, String dispositivoId) {
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
  }

  void _iniciarSincronizacaoPeriodica() {
    if (_syncService == null || _timerSincronizacao != null) return;
    // Lê `_syncService` de novo a cada tick (em vez de capturar uma
    // referência fixa aqui) porque ele pode ser substituído por
    // `_configurarServicosSincronizacao` depois que o timer já está
    // rodando — ex: o endereço do Backend muda ao descobrir via mDNS no
    // retorno de foco (ver #28) ou ao salvar um novo endereço manual.
    _timerSincronizacao = Timer.periodic(
      _intervaloSincronizacao,
      (_) => _syncService?.sincronizar(),
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

  /// Abre a tela de Pareamento e, ao voltar, recarrega o Dispositivo
  /// pareado e reinicializa a sincronização — não basta o valor lido em
  /// [_inicializarSincronizacao], já que o app pode ter sido aberto antes
  /// do Backend ser configurado ou do Pareamento ser confirmado (ver #15):
  /// nesse caso [_syncService] também ainda não existia.
  Future<void> _abrirPareamento() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            PairingScreen(enderecoBackendLocal: widget.enderecoBackendLocal),
      ),
    );

    final dispositivoPareadoId = await _pairedDeviceStore.obter();
    if (!mounted) return;
    setState(() => _dispositivoPareadoId = dispositivoPareadoId);

    if (_syncService == null) {
      await _inicializarSincronizacao();
    }
  }

  /// Remove o Documento [hash] da Biblioteca (ver #20), lendo [_syncService]
  /// só no momento da exclusão (não quando a [BibliotecaScreen] é
  /// construída): evita perder o cancelamento na Fila Local se o Backend
  /// ainda estiver sendo configurado em [_inicializarSincronizacao] quando
  /// a tela abre, mas já estiver disponível quando o usuário excluir.
  Future<void> _removerDocumento(String hash) async {
    final syncService = _syncService;
    if (syncService != null) {
      await syncService.removerDocumento(hash);
    } else {
      await _bibliotecaStore.remover(hash);
    }
  }

  Future<void> _abrirSeletorTema() async {
    final temaEscolhido = await showDialog<ThemeMode>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Tema'),
        children: [
          RadioGroup<ThemeMode>(
            groupValue: widget.temaAtual,
            onChanged: (tema) => Navigator.of(context).pop(tema),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: ThemeMode.values.map((tema) {
                return RadioListTile<ThemeMode>(
                  title: Text(_nomeTema(tema)),
                  value: tema,
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );

    if (temaEscolhido != null) {
      widget.onSelecionarTema(temaEscolhido);
    }
  }

  /// Permite configurar manualmente o endereço do Backend no celular — o
  /// fallback explícito para quando a descoberta mDNS falha
  /// persistentemente (ex: rede com isolamento de cliente, multicast
  /// bloqueado), já que nesse caso o celular nunca teria outra forma de
  /// obter o endereço (ver #28).
  Future<void> _abrirConfiguracaoBackendManual() async {
    final urlSalva = await _backendUrlStore.obter();
    if (!mounted) return;

    final formKey = GlobalKey<FormState>();
    final controller = TextEditingController(text: urlSalva ?? '');

    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Backend manual'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'http://192.168.1.10:5119',
            ),
            keyboardType: TextInputType.url,
            validator: validarUrlBackendObrigatoria,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              Navigator.of(context).pop(true);
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );

    final url = controller.text.trim();
    controller.dispose();
    if (confirmado != true) return;

    await _backendUrlStore.salvar(url);
    if (!mounted) return;

    final dispositivoId = _dispositivoId ?? await _deviceIdStore.obterOuCriar();
    if (!mounted) return;
    _dispositivoId = dispositivoId;
    _configurarServicosSincronizacao(url, dispositivoId);
    unawaited(_syncService!.sincronizar());
    _iniciarSincronizacaoPeriodica();
  }

  void _abrirBiblioteca() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BibliotecaScreen(
          bibliotecaStore: _bibliotecaStore,
          removerDocumento: _removerDocumento,
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
                if (_ehDispositivoMovel) ...[
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: _abrirConfiguracaoBackendManual,
                    icon: const Icon(Icons.dns),
                    label: const Text('Backend manual'),
                  ),
                ],
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _abrirSeletorTema,
                  icon: const Icon(Icons.brightness_6),
                  label: const Text('Tema'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
