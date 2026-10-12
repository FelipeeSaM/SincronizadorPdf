/// Um dos retângulos que compõem o desenho de um Highlight sobre o texto
/// selecionado, em coordenadas de página do PDF (origem no canto inferior
/// esquerdo, eixo Y para cima — mesma convenção usada pelo `pdfrx`). Uma
/// seleção que cruza mais de uma linha gera um retângulo por linha, em vez
/// de um único retângulo grosseiro cobrindo tudo (ADR-0001).
class HighlightRect {
  const HighlightRect({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });

  final double left;
  final double top;
  final double right;
  final double bottom;

  Map<String, dynamic> toJson() => {
    'left': left,
    'top': top,
    'right': right,
    'bottom': bottom,
  };

  factory HighlightRect.fromJson(Map<String, dynamic> json) => HighlightRect(
    left: (json['left'] as num).toDouble(),
    top: (json['top'] as num).toDouble(),
    right: (json['right'] as num).toDouble(),
    bottom: (json['bottom'] as num).toDouble(),
  );
}

/// Um Highlight (ver CONTEXT.md): grifo visual permanente sobre um trecho
/// de texto de um Documento, numa única página, desenhado como overlay
/// pelo Visualizador a partir de [rects] (ADR-0001).
///
/// [localId] identifica o Highlight neste Dispositivo desde a criação,
/// antes mesmo de ser aceito pelo Backend — necessário porque a criação
/// pode ficar retida na Fila Local de Sincronização (ADR-0005) até o
/// Backend confirmar e atribuir [remoteId]. Um Highlight visto pela
/// primeira vez vindo do Backend (criado no Dispositivo pareado) usa o
/// próprio [remoteId] como [localId].
class Highlight {
  const Highlight({
    required this.localId,
    this.remoteId,
    required this.page,
    required this.rects,
    this.trechoTexto,
    required this.criadoEm,
  });

  final String localId;
  final String? remoteId;
  final int page;
  final List<HighlightRect> rects;
  final String? trechoTexto;
  final DateTime criadoEm;

  Highlight comRemoteId(String remoteId) => Highlight(
    localId: localId,
    remoteId: remoteId,
    page: page,
    rects: rects,
    trechoTexto: trechoTexto,
    criadoEm: criadoEm,
  );

  Map<String, dynamic> toJson() => {
    'localId': localId,
    'remoteId': remoteId,
    'page': page,
    'rects': rects.map((r) => r.toJson()).toList(),
    'trechoTexto': trechoTexto,
    'criadoEm': criadoEm.toUtc().toIso8601String(),
  };

  factory Highlight.fromJson(Map<String, dynamic> json) => Highlight(
    localId: json['localId'] as String,
    remoteId: json['remoteId'] as String?,
    page: json['page'] as int,
    rects: (json['rects'] as List<dynamic>)
        .map((r) => HighlightRect.fromJson(r as Map<String, dynamic>))
        .toList(),
    trechoTexto: json['trechoTexto'] as String?,
    criadoEm: DateTime.parse(json['criadoEm'] as String),
  );
}
