import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

import 'biblioteca/documento_biblioteca.dart';
import 'sync/highlight.dart';
import 'sync/highlight_sync_service.dart';
import 'sync/posicao_leitura.dart';
import 'sync/reading_position_sync_service.dart';

const _intervaloSincronizacao = Duration(seconds: 5);
const _debouncePosicaoLocal = Duration(milliseconds: 400);
const _esperaFadeOutNome = Duration(seconds: 3);
const _duracaoFadeNome = Duration(seconds: 1);

/// Largura do trilho da barra de rolagem lateral (ver #23).
const _larguraBarraRolagem = 14.0;

/// Altura mínima do indicador de posição dentro da barra, para que
/// permaneça alvo de toque viável em Documentos muito longos (onde a
/// fração correspondente à área visível seria, do contrário, minúscula).
const _alturaMinimaIndicadorRolagem = 32.0;

/// Distância do indicador até as bordas do trilho da barra de rolagem.
const _margemIndicadorRolagem = 2.0;

/// Cor de preenchimento usada para desenhar o overlay de Highlight sobre o
/// texto selecionado (ver ADR-0001): o PDF original nunca é modificado.
const _corHighlight = Color(0x664CAF50);

/// Abre [documento] da Biblioteca no visualizador, empilhando a tela sobre
/// [context]. Se [posicaoLeituraSyncService] for informado, a Posição de
/// Leitura do Documento é reconciliada com o Backend ao abrir e enquanto a
/// tela estiver em foco (ver #8, ADR-0005). Se [highlightSyncService] for
/// informado, o mesmo vale para os Highlights do Documento (ver #11).
Future<void> abrirNoVisualizador(
  BuildContext context,
  DocumentoBiblioteca documento, {
  ReadingPositionSyncService? posicaoLeituraSyncService,
  HighlightSyncService? highlightSyncService,
}) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => DocumentoViewerScreen(
        caminhoDocumento: documento.caminhoArquivo,
        nomeDocumento: documento.nome,
        hash: documento.hash,
        posicaoLeituraSyncService: posicaoLeituraSyncService,
        highlightSyncService: highlightSyncService,
      ),
    ),
  );
}

/// Calcula o percentual de rolagem (ver CONTEXT.md) dentro de [pagina]:
/// a fração da altura da página já rolada para cima do topo da área
/// visível [visivel], entre 0.0 (topo da página) e 1.0 (fim da página).
double calcularPercentualRolagem({
  required Rect pagina,
  required Rect visivel,
}) {
  if (pagina.height <= 0) return 0;
  return ((visivel.top - pagina.top) / pagina.height).clamp(0.0, 1.0);
}

/// Calcula a posição e a altura do indicador da barra de rolagem lateral
/// (ver #23): a fração de [visivel] dentro de um Documento de altura
/// [alturaDocumento], projetada sobre um trilho de altura [alturaTrilho].
///
/// A altura do indicador nunca fica abaixo de [alturaMinima] — do
/// contrário, em Documentos muito longos, a fração da área visível seria
/// minúscula demais para ser um alvo de toque viável.
({double topo, double altura}) calcularIndicadorRolagem({
  required double alturaTrilho,
  required double alturaDocumento,
  required Rect visivel,
  required double alturaMinima,
}) {
  if (alturaDocumento <= 0 || alturaTrilho <= 0) {
    return (topo: 0.0, altura: 0.0);
  }

  final topoFracao = (visivel.top / alturaDocumento).clamp(0.0, 1.0);
  final alturaFracao = (visivel.height / alturaDocumento).clamp(0.0, 1.0);

  // `alturaMinima` só é um limite inferior válido para o clamp abaixo
  // enquanto o trilho for maior que ela — do contrário (trilho menor que
  // a altura mínima, o que pode acontecer num frame transitório durante
  // redimensionar/maximizar a janela) o próprio trilho vira o teto real.
  final limiteInferiorAltura = alturaMinima < alturaTrilho
      ? alturaMinima
      : alturaTrilho;
  final altura = (alturaFracao * alturaTrilho).clamp(
    limiteInferiorAltura,
    alturaTrilho,
  );
  final topo = (topoFracao * alturaTrilho).clamp(0.0, alturaTrilho - altura);

  return (topo: topo, altura: altura);
}

/// Decide o efeito de um toque em [posicaoLocal] (coordenada vertical, em
/// pixels do trilho) no início de um arrasto da barra de rolagem lateral
/// (ver #23).
///
/// Se o toque cai dentro do indicador (entre [indicadorTopo] e
/// [indicadorTopo] + [indicadorAltura]), só guarda o deslocamento até o
/// seu topo — sem navegar ainda, do contrário o indicador saltaria para
/// ficar com o topo embaixo do dedo no instante em que o arrasto começa.
/// Caso contrário (toque em outro ponto do trilho), equivale a um clique
/// de "ir para esta posição": [fracaoParaNavegar] não vem nulo, pedindo
/// navegação imediata, e o deslocamento é zerado porque esse ponto passa
/// a ser a nova referência.
({double offsetArrasto, double? fracaoParaNavegar}) calcularInicioArrasto({
  required double posicaoLocal,
  required double indicadorTopo,
  required double indicadorAltura,
  required double alturaTrilho,
}) {
  final dentroDoIndicador =
      posicaoLocal >= indicadorTopo &&
      posicaoLocal <= indicadorTopo + indicadorAltura;
  if (dentroDoIndicador) {
    return (offsetArrasto: posicaoLocal - indicadorTopo, fracaoParaNavegar: null);
  }
  return (offsetArrasto: 0.0, fracaoParaNavegar: posicaoLocal / alturaTrilho);
}

/// Converte um trecho de texto selecionado [range] (ver `pdfrx`) para os
/// retângulos que desenham o Highlight sobre ele: um retângulo por linha
/// de texto abrangida pela seleção, em vez de um único retângulo
/// grosseiro que também cobriria o espaço entre linhas quando a seleção
/// cruza mais de uma (ADR-0001).
List<HighlightRect> retangulosDaSelecao(PdfPageTextRange range) => [
  for (final fragmento in range.enumerateFragmentBoundingRects())
    HighlightRect(
      left: fragmento.bounds.left,
      top: fragmento.bounds.top,
      right: fragmento.bounds.right,
      bottom: fragmento.bounds.bottom,
    ),
];

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
    required this.nomeDocumento,
    required this.hash,
    this.posicaoLeituraSyncService,
    this.highlightSyncService,
  });

  /// Caminho local do arquivo PDF a ser exibido.
  final String caminhoDocumento;

  /// Nome de exibição do Documento (ver [DocumentoBiblioteca.nome]),
  /// mostrado no cabeçalho — não deve ser derivado de [caminhoDocumento],
  /// que é sempre `<hash>.pdf` na Biblioteca (ver #19).
  final String nomeDocumento;

  /// Hash do conteúdo do Documento, sua identidade entre Dispositivos.
  final String hash;

  /// Reconciliação da Posição de Leitura com o Backend; `null` quando não
  /// há Backend configurado (ver [abrirNoVisualizador]).
  final ReadingPositionSyncService? posicaoLeituraSyncService;

  /// Criação, remoção e sincronização dos Highlights com o Backend;
  /// `null` quando não há Backend configurado (ver [abrirNoVisualizador]).
  final HighlightSyncService? highlightSyncService;

  @override
  State<DocumentoViewerScreen> createState() => _DocumentoViewerScreenState();
}

class _DocumentoViewerScreenState extends State<DocumentoViewerScreen>
    with WidgetsBindingObserver {
  final _controller = PdfViewerController();

  Timer? _timerSincronizacao;
  Timer? _debounceRolagem;
  Timer? _timerFadeOutNome;
  PosicaoLeitura? _posicaoInicial;
  bool _carregandoPosicaoInicial = true;
  List<Highlight> _highlights = [];

  // Nome do Documento no cabeçalho: visível ao abrir, some após
  // `_esperaFadeOutNome` parado e volta a aparecer a cada rolagem (#21).
  bool _nomeVisivel = true;

  // Só true a partir de `onViewerReady`: antes disso, `layout`,
  // `documentSize` e `visibleRect` do controller ainda não existem.
  bool _visualizadorPronto = false;

  // A barra de rolagem lateral (#23) só aparece no PC: no celular, o
  // gesto direto de rolagem já é suficiente e a barra ocuparia espaço de
  // tela sem necessidade. Quando exibida, fica sempre visível, sem o
  // fade do cabeçalho — não compete pelo mesmo espaço de leitura.
  final bool _exibirBarraRolagem = !(Platform.isAndroid || Platform.isIOS);

  // Deslocamento (em pixels do trilho) entre o ponto tocado e o topo do
  // indicador no início do arrasto — preserva esse deslocamento durante
  // todo o gesto para o indicador não "saltar" sob o dedo quando o
  // toque não cai exatamente no seu topo (ver #23).
  double _offsetArrastoIndicadorRolagem = 0;

  // Assume em foco ao montar: a tela só é construída enquanto visível.
  // Atualizado só depois pelas transições reportadas a `didChangeAppLifecycleState`.
  bool _emFoco = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller.addListener(_aoRolar);
    _reiniciarTimerFadeOutNome();
    unawaited(_carregarEstadoInicial());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.removeListener(_aoRolar);
    _debounceRolagem?.cancel();
    _timerFadeOutNome?.cancel();
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

  Future<void> _carregarEstadoInicial() async {
    final posicaoSyncService = widget.posicaoLeituraSyncService;
    final highlightSyncService = widget.highlightSyncService;

    final posicao = posicaoSyncService == null
        ? null
        : await posicaoSyncService.sincronizar(widget.hash);
    final highlights = highlightSyncService == null
        ? <Highlight>[]
        : await highlightSyncService.sincronizar(widget.hash);

    if (!mounted) return;
    setState(() {
      _posicaoInicial = posicao;
      _highlights = highlights;
      _carregandoPosicaoInicial = false;
    });
    _iniciarSincronizacaoPeriodica();
  }

  void _iniciarSincronizacaoPeriodica() {
    final temServicoDeSincronizacao =
        widget.posicaoLeituraSyncService != null ||
        widget.highlightSyncService != null;
    if (!temServicoDeSincronizacao || !_emFoco || _timerSincronizacao != null) {
      return;
    }
    _timerSincronizacao = Timer.periodic(
      _intervaloSincronizacao,
      (_) => _sincronizarPeriodicamente(),
    );
  }

  Future<void> _sincronizarPeriodicamente() async {
    await widget.posicaoLeituraSyncService?.sincronizar(widget.hash);

    final highlightSyncService = widget.highlightSyncService;
    if (highlightSyncService == null) return;

    final highlights = await highlightSyncService.sincronizar(widget.hash);
    if (!mounted) return;
    setState(() => _highlights = highlights);
  }

  void _pararSincronizacaoPeriodica() {
    _timerSincronizacao?.cancel();
    _timerSincronizacao = null;
  }

  void _aoRolar() {
    // Suspende o fade out enquanto a rolagem continuar — o nome só é
    // trazido de volta (fade in) quando ela termina, abaixo.
    _timerFadeOutNome?.cancel();
    _debounceRolagem?.cancel();
    _debounceRolagem = Timer(_debouncePosicaoLocal, () {
      _salvarPosicaoAtualLocal();
      _mostrarNomeDocumento();
      _reiniciarTimerFadeOutNome();
    });
  }

  void _mostrarNomeDocumento() {
    if (!_nomeVisivel) setState(() => _nomeVisivel = true);
  }

  void _reiniciarTimerFadeOutNome() {
    _timerFadeOutNome?.cancel();
    _timerFadeOutNome = Timer(_esperaFadeOutNome, _esconderNomeDocumento);
  }

  void _esconderNomeDocumento() {
    if (!mounted) return;
    setState(() => _nomeVisivel = false);
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
    // Adiado para depois do frame atual: chamar `setState` direto aqui,
    // dentro do próprio callback de pronto do `pdfrx`, reconstrói a tela
    // (e portanto o `PdfViewer`) de forma reentrante, no meio da própria
    // inicialização dele — o que nesse ambiente deixava a tela presa em
    // preto (ver #23).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _visualizadorPronto = true);
    });

    final posicao = _posicaoInicial;
    if (posicao == null) return;

    final pagina = posicao.pagina.clamp(1, controller.pageCount);
    final pageLayout = _pageLayout(pagina);
    final y = pageLayout.top + posicao.percentualRolagem * pageLayout.height;
    unawaited(
      controller.goToPosition(documentOffset: Offset(pageLayout.left, y)),
    );
  }

  /// Navega para a posição vertical do Documento correspondente a
  /// [fracao] (0.0 = topo, 1.0 = fim), mantendo a rolagem horizontal
  /// atual — usado tanto ao tocar quanto ao arrastar a barra de rolagem
  /// lateral (ver #23).
  void _navegarParaFracaoDoDocumento(double fracao) {
    if (!_visualizadorPronto) return;

    final alturaDocumento = _controller.documentSize.height;
    final y = fracao.clamp(0.0, 1.0) * alturaDocumento;
    unawaited(
      _controller.goToPosition(
        documentOffset: Offset(_controller.visibleRect.left, y),
      ),
    );
  }

  Rect _pageLayout(int pagina) => _controller.layout.pageLayouts[pagina - 1];

  /// Desenha o overlay de cada Highlight conhecido de [page] (ver
  /// ADR-0001), chamado pelo `pdfrx` a cada repintura da página.
  void _pintarHighlights(Canvas canvas, Rect pageRect, PdfPage page) {
    final tinta = Paint()..color = _corHighlight;
    for (final highlight in _highlights) {
      if (highlight.page != page.pageNumber) continue;
      for (final rect in highlight.rects) {
        canvas.drawRect(_retanguloNoDocumento(rect, page, pageRect), tinta);
      }
    }
  }

  Rect _retanguloNoDocumento(HighlightRect rect, PdfPage page, Rect pageRect) =>
      PdfRect(
        rect.left,
        rect.top,
        rect.right,
        rect.bottom,
      ).toRectInDocument(page: page, pageRect: pageRect);

  /// Acrescenta o botão "Destacar" ao menu de contexto da seleção de
  /// texto, responsável por criar o Highlight (ver [_criarHighlightDaSelecao]).
  /// Sem [HighlightSyncService] configurado ou sem texto selecionado (ex:
  /// Documento sem camada de texto), não acrescenta nada — a seleção
  /// continua funcionando normalmente, apenas sem a opção de Highlight.
  void _personalizarMenuContexto(
    PdfViewerContextMenuBuilderParams params,
    List<ContextMenuButtonItem> items,
  ) {
    if (widget.highlightSyncService == null) return;
    if (!params.isTextSelectionEnabled ||
        !params.textSelectionDelegate.hasSelectedText) {
      return;
    }

    items.add(
      ContextMenuButtonItem(
        label: 'Destacar',
        onPressed: () => unawaited(_criarHighlightDaSelecao(params)),
      ),
    );
  }

  Future<void> _criarHighlightDaSelecao(
    PdfViewerContextMenuBuilderParams params,
  ) async {
    final highlightSyncService = widget.highlightSyncService;
    if (highlightSyncService == null) return;

    final ranges = await params.textSelectionDelegate.getSelectedTextRanges();
    await params.textSelectionDelegate.clearTextSelection();
    params.dismissContextMenu();

    for (final range in ranges) {
      final rects = retangulosDaSelecao(range);
      if (rects.isEmpty) continue;

      final highlight = await highlightSyncService.criar(
        hash: widget.hash,
        page: range.pageNumber,
        rects: rects,
        trechoTexto: range.text,
      );
      if (!mounted) return;
      setState(() => _highlights = [..._highlights, highlight]);
    }
  }

  /// Trata o toque simples sobre o visualizador: se cair sobre um
  /// Highlight existente, apaga-o e consome o toque; caso contrário,
  /// devolve o controle ao `pdfrx` para o tratamento padrão.
  bool _aoTocarNoVisualizador(
    BuildContext context,
    PdfViewerController controller,
    PdfViewerGeneralTapHandlerDetails details,
  ) {
    if (widget.highlightSyncService == null) return false;
    if (details.type != PdfViewerGeneralTapType.tap) return false;

    final highlight = _highlightTocado(details.documentPosition);
    if (highlight == null) return false;

    unawaited(_apagarHighlight(highlight));
    return true;
  }

  Highlight? _highlightTocado(Offset posicaoNoDocumento) {
    const margem = 4.0;

    for (final highlight in _highlights) {
      final indicePagina = highlight.page - 1;
      if (indicePagina < 0 || indicePagina >= _controller.pages.length) {
        continue;
      }

      final pageRect = _controller.layout.pageLayouts[indicePagina];
      if (!pageRect.contains(posicaoNoDocumento)) continue;

      final page = _controller.pages[indicePagina];
      for (final rect in highlight.rects) {
        final area = _retanguloNoDocumento(
          rect,
          page,
          pageRect,
        ).inflate(margem);
        if (area.contains(posicaoNoDocumento)) return highlight;
      }
    }
    return null;
  }

  Future<void> _apagarHighlight(Highlight highlight) async {
    final highlightSyncService = widget.highlightSyncService;
    if (highlightSyncService == null) return;

    setState(
      () => _highlights = _highlights
          .where((h) => h.localId != highlight.localId)
          .toList(),
    );
    await highlightSyncService.apagar(hash: widget.hash, highlight: highlight);
  }

  /// Cabeçalho flutuante sobreposto ao Documento (não o `appBar` do
  /// `Scaffold`): preso a esse slot, a faixa continuaria ocupando espaço
  /// de leitura mesmo com opacidade zero, porque o fundo do `Scaffold`
  /// aparece por trás dela — o motivo original da #21 era justamente
  /// devolver esse espaço. `IgnorePointer` evita que a seta de voltar
  /// continue clicável enquanto está invisível.
  Widget _buildCabecalhoFlutuante() => Positioned(
    top: 0,
    left: 0,
    right: 0,
    child: IgnorePointer(
      ignoring: !_nomeVisivel,
      child: AnimatedOpacity(
        opacity: _nomeVisivel ? 1.0 : 0.0,
        duration: _duracaoFadeNome,
        child: SafeArea(
          bottom: false,
          child: AppBar(title: Text(widget.nomeDocumento)),
        ),
      ),
    ),
  );

  /// Barra de rolagem lateral: reflete a posição/extensão atual da área
  /// visível dentro do Documento e permite arrastar (ou tocar em qualquer
  /// ponto do trilho) para navegar — scrubbing, não só indicação visual
  /// (ver #23). Só no PC (`_exibirBarraRolagem`) e sempre visível ali,
  /// sem o fade do cabeçalho.
  ///
  /// Construída via `viewerOverlayBuilder` (ponto de extensão oficial do
  /// `pdfrx` para overlays sobre o Documento, usado por exemplo pelo seu
  /// próprio `PdfViewerScrollThumb`) em vez de um `Positioned` irmão num
  /// `Stack` externo ao `PdfViewer`: colocá-la fora, sobrepondo o
  /// Documento a partir de um `Stack` nosso, deixava a tela presa em
  /// preto nesse ambiente assim que o visualizador ficava pronto — mesmo
  /// com um `Container` estático, sem nenhuma lógica. Dentro do
  /// `viewerOverlayBuilder`, o widget entra no `Stack` que o próprio
  /// `pdfrx` já gerencia internamente (que já empilha vários overlays
  /// sem esse problema), e é reconstruído automaticamente a cada
  /// mudança relevante do `_controller`, sem precisarmos de um
  /// `AnimatedBuilder` próprio.
  ///
  /// Só é construída depois de `_visualizadorPronto`: antes disso,
  /// `documentSize`/`visibleRect` do controller ainda não existem.
  List<Widget> _buildOverlaysDoVisualizador(
    BuildContext context,
    Size size,
    PdfViewerHandleLinkTap handleLinkTap,
  ) {
    if (!_exibirBarraRolagem || !_visualizadorPronto) return const [];

    return [
      Positioned(
        top: 0,
        right: 0,
        width: _larguraBarraRolagem,
        height: size.height,
        child: _buildIndicadorRolagem(size.height),
      ),
    ];
  }

  Widget _buildIndicadorRolagem(double alturaTrilho) {
    final indicador = calcularIndicadorRolagem(
      alturaTrilho: alturaTrilho,
      alturaDocumento: _controller.documentSize.height,
      visivel: _controller.visibleRect,
      alturaMinima: _alturaMinimaIndicadorRolagem,
    );
    if (indicador.altura <= 0) return const SizedBox.shrink();

    void iniciarArrasto(Offset posicaoLocal) {
      final resultado = calcularInicioArrasto(
        posicaoLocal: posicaoLocal.dy,
        indicadorTopo: indicador.topo,
        indicadorAltura: indicador.altura,
        alturaTrilho: alturaTrilho,
      );
      _offsetArrastoIndicadorRolagem = resultado.offsetArrasto;
      final fracao = resultado.fracaoParaNavegar;
      if (fracao != null) _navegarParaFracaoDoDocumento(fracao);
    }

    void arrastarIndicador(Offset posicaoLocal) {
      final novoTopo = posicaoLocal.dy - _offsetArrastoIndicadorRolagem;
      _navegarParaFracaoDoDocumento(novoTopo / alturaTrilho);
    }

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTapDown: (details) => iniciarArrasto(details.localPosition),
      onVerticalDragStart: (details) => iniciarArrasto(details.localPosition),
      onVerticalDragUpdate: (details) => arrastarIndicador(details.localPosition),
      child: SizedBox(
        height: alturaTrilho,
        width: _larguraBarraRolagem,
        child: Stack(
          children: [
            Positioned(
              top: indicador.topo,
              right: _margemIndicadorRolagem,
              width: _larguraBarraRolagem - _margemIndicadorRolagem * 2,
              height: indicador.altura,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(_larguraBarraRolagem / 2),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_carregandoPosicaoInicial) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.nomeDocumento)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: PdfViewer.file(
              widget.caminhoDocumento,
              controller: _controller,
              initialPageNumber: _posicaoInicial?.pagina ?? 1,
              // PdfViewerParams sem `layoutPages` customizado usa o layout
              // padrão do pdfrx, que empilha as páginas verticalmente
              // formando uma única rolagem contínua por todo o Documento
              // (não é um viewer paginado).
              params: PdfViewerParams(
                textSelectionParams: const PdfTextSelectionParams(
                  enabled: true,
                ),
                onViewerReady: _aoFicarPronto,
                pagePaintCallbacks: [_pintarHighlights],
                customizeContextMenuItems: _personalizarMenuContexto,
                onGeneralTap: _aoTocarNoVisualizador,
                viewerOverlayBuilder: _buildOverlaysDoVisualizador,
              ),
            ),
          ),
          _buildCabecalhoFlutuante(),
        ],
      ),
    );
  }
}
