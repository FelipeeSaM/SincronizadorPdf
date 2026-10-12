import 'dart:async';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:pdfrx/pdfrx.dart';

import 'biblioteca/documento_biblioteca.dart';
import 'sync/posicao_leitura.dart';
import 'sync/reading_position_sync_service.dart';

const _intervaloSincronizacaoPosicao = Duration(seconds: 5);
const _debouncePosicaoLocal = Duration(milliseconds: 400);

/// Abre [documento] da Biblioteca no visualizador, empilhando a tela sobre
/// [context]. Se [posicaoLeituraSyncService] for informado, a Posição de
/// Leitura do Documento é reconciliada com o Backend ao abrir e enquanto a
/// tela estiver em foco (ver #8, ADR-0005).
Future<void> abrirNoVisualizador(
  BuildContext context,
  DocumentoBiblioteca documento, {
  ReadingPositionSyncService? posicaoLeituraSyncService,
}) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => DocumentoViewerScreen(
        caminhoDocumento: documento.caminhoArquivo,
        hash: documento.hash,
        posicaoLeituraSyncService: posicaoLeituraSyncService,
      ),
    ),
  );
}

/// Calcula o percentual de rolagem (ver CONTEXT.md) dentro de [pagina]:
/// a fração da altura da página já rolada para cima do topo da área
/// visível [visivel], entre 0.0 (topo da página) e 1.0 (fim da página).
double calcularPercentualRolagem({required Rect pagina, required Rect visivel}) {
  if (pagina.height <= 0) return 0;
  return ((visivel.top - pagina.top) / pagina.height).clamp(0.0, 1.0);
}

/// Tela de visualização local de um Documento (PDF) escolhido pelo usuário.
///
/// Renderiza o Documento em rolagem contínua por todas as páginas (não
/// paginada), com seleção de texto habilitada quando o Documento tiver
/// camada de texto. Documentos escaneados sem texto continuam abrindo e
/// rolando normalmente, apenas sem seleção disponível.
class DocumentoViewerScreen extends StatefulWidget {
  const DocumentoViewerScreen({
    super.key,
    required this.caminhoDocumento,
    required this.hash,
    this.posicaoLeituraSyncService,
  });

  /// Caminho local do arquivo PDF a ser exibido.
  final String caminhoDocumento;

  /// Hash do conteúdo do Documento, sua identidade entre Dispositivos.
  final String hash;

  /// Reconciliação da Posição de Leitura com o Backend; `null` quando não
  /// há Backend configurado (ver [abrirNoVisualizador]).
  final ReadingPositionSyncService? posicaoLeituraSyncService;

  @override
  State<DocumentoViewerScreen> createState() => _DocumentoViewerScreenState();
}

class _DocumentoViewerScreenState extends State<DocumentoViewerScreen>
    with WidgetsBindingObserver {
  final _controller = PdfViewerController();

  Timer? _timerSincronizacao;
  Timer? _debounceRolagem;
  PosicaoLeitura? _posicaoInicial;
  bool _carregandoPosicaoInicial = true;

  // Assume em foco ao montar: a tela só é construída enquanto visível.
  // Atualizado só depois pelas transições reportadas a `didChangeAppLifecycleState`.
  bool _emFoco = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller.addListener(_aoRolar);
    unawaited(_carregarPosicaoInicial());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.removeListener(_aoRolar);
    _debounceRolagem?.cancel();
    _pararSincronizacaoPeriodica();
    _salvarPosicaoAtualLocal();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // A sincronização só ocorre com a tela em foco, sem serviço em segundo
    // plano (ver ADR-0005).
    _emFoco = state == AppLifecycleState.resumed;
    if (_emFoco) {
      _iniciarSincronizacaoPeriodica();
    } else {
      _pararSincronizacaoPeriodica();
    }
  }

  Future<void> _carregarPosicaoInicial() async {
    final syncService = widget.posicaoLeituraSyncService;
    final posicao = syncService == null
        ? null
        : await syncService.sincronizar(widget.hash);

    if (!mounted) return;
    setState(() {
      _posicaoInicial = posicao;
      _carregandoPosicaoInicial = false;
    });
    _iniciarSincronizacaoPeriodica();
  }

  void _iniciarSincronizacaoPeriodica() {
    final syncService = widget.posicaoLeituraSyncService;
    if (syncService == null || !_emFoco || _timerSincronizacao != null) return;
    _timerSincronizacao = Timer.periodic(
      _intervaloSincronizacaoPosicao,
      (_) => syncService.sincronizar(widget.hash),
    );
  }

  void _pararSincronizacaoPeriodica() {
    _timerSincronizacao?.cancel();
    _timerSincronizacao = null;
  }

  void _aoRolar() {
    _debounceRolagem?.cancel();
    _debounceRolagem = Timer(_debouncePosicaoLocal, _salvarPosicaoAtualLocal);
  }

  void _salvarPosicaoAtualLocal() {
    final syncService = widget.posicaoLeituraSyncService;
    if (syncService == null || !_controller.isReady) return;

    final pagina = _controller.pageNumber;
    if (pagina == null) return;

    final percentual = calcularPercentualRolagem(
      pagina: _pageLayout(pagina),
      visivel: _controller.visibleRect,
    );

    unawaited(
      syncService.atualizarLocal(
        hash: widget.hash,
        pagina: pagina,
        percentualRolagem: percentual,
      ),
    );
  }

  void _aoFicarPronto(PdfDocument document, PdfViewerController controller) {
    final posicao = _posicaoInicial;
    if (posicao == null) return;

    final pagina = posicao.pagina.clamp(1, controller.pageCount);
    final pageLayout = _pageLayout(pagina);
    final y = pageLayout.top + posicao.percentualRolagem * pageLayout.height;
    unawaited(
      controller.goToPosition(documentOffset: Offset(pageLayout.left, y)),
    );
  }

  Rect _pageLayout(int pagina) => _controller.layout.pageLayouts[pagina - 1];

  @override
  Widget build(BuildContext context) {
    final nomeDocumento = p.basename(widget.caminhoDocumento);

    if (_carregandoPosicaoInicial) {
      return Scaffold(
        appBar: AppBar(title: Text(nomeDocumento)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(nomeDocumento)),
      body: PdfViewer.file(
        widget.caminhoDocumento,
        controller: _controller,
        initialPageNumber: _posicaoInicial?.pagina ?? 1,
        // PdfViewerParams sem `layoutPages` customizado usa o layout padrão
        // do pdfrx, que empilha as páginas verticalmente formando uma única
        // rolagem contínua por todo o Documento (não é um viewer paginado).
        params: PdfViewerParams(
          textSelectionParams: const PdfTextSelectionParams(enabled: true),
          onViewerReady: _aoFicarPronto,
        ),
      ),
    );
  }
}
