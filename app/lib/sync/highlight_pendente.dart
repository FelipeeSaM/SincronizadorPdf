import 'highlight.dart';

/// Uma criação de Highlight ainda não aceita pelo Backend, retida na Fila
/// Local de Sincronização (ADR-0005) até ele responder. Não guarda
/// [Highlight.criadoEm]: a entrada correspondente já existe na
/// `HighlightStore` local sob o mesmo [localId], de onde o timestamp é
/// lido quando necessário.
class HighlightPendenteCriacao {
  const HighlightPendenteCriacao({
    required this.localId,
    required this.hash,
    required this.page,
    required this.rects,
    this.trechoTexto,
  });

  final String localId;
  final String hash;
  final int page;
  final List<HighlightRect> rects;
  final String? trechoTexto;

  Map<String, dynamic> toJson() => {
    'localId': localId,
    'hash': hash,
    'page': page,
    'rects': rects.map((r) => r.toJson()).toList(),
    'trechoTexto': trechoTexto,
  };

  factory HighlightPendenteCriacao.fromJson(Map<String, dynamic> json) =>
      HighlightPendenteCriacao(
        localId: json['localId'] as String,
        hash: json['hash'] as String,
        page: json['page'] as int,
        rects: (json['rects'] as List<dynamic>)
            .map((r) => HighlightRect.fromJson(r as Map<String, dynamic>))
            .toList(),
        trechoTexto: json['trechoTexto'] as String?,
      );
}

/// Uma remoção de Highlight já sincronizado (com [remoteId] conhecido)
/// ainda não aceita pelo Backend, retida na Fila Local de Sincronização
/// (ADR-0005) até ele responder.
class HighlightPendenteRemocao {
  const HighlightPendenteRemocao({
    required this.localId,
    required this.hash,
    required this.remoteId,
  });

  final String localId;
  final String hash;
  final String remoteId;

  Map<String, dynamic> toJson() => {
    'localId': localId,
    'hash': hash,
    'remoteId': remoteId,
  };

  factory HighlightPendenteRemocao.fromJson(Map<String, dynamic> json) =>
      HighlightPendenteRemocao(
        localId: json['localId'] as String,
        hash: json['hash'] as String,
        remoteId: json['remoteId'] as String,
      );
}
