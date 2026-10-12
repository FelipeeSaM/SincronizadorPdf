/// Um Documento cujo arquivo completo já chegou a este Dispositivo,
/// disponível para reabertura na Biblioteca.
class DocumentoBiblioteca {
  const DocumentoBiblioteca({
    required this.hash,
    required this.nome,
    required this.caminhoArquivo,
    required this.recebidoEm,
    this.enviadoPara = const [],
  });

  final String hash;
  final String nome;
  final String caminhoArquivo;
  final DateTime recebidoEm;

  /// Dispositivos pareados para os quais este Documento já foi entregue com
  /// sucesso ao Backend (ver [DocumentSyncService.abrirDocumento] — usado
  /// para não tentar reenviar ao reabrir um Documento já entregue).
  final List<String> enviadoPara;

  DocumentoBiblioteca comEnviadoPara(String destinoDispositivoId) =>
      DocumentoBiblioteca(
        hash: hash,
        nome: nome,
        caminhoArquivo: caminhoArquivo,
        recebidoEm: recebidoEm,
        enviadoPara: [...enviadoPara, destinoDispositivoId],
      );

  Map<String, dynamic> toJson() => {
    'hash': hash,
    'nome': nome,
    'caminhoArquivo': caminhoArquivo,
    'recebidoEm': recebidoEm.toIso8601String(),
    'enviadoPara': enviadoPara,
  };

  factory DocumentoBiblioteca.fromJson(Map<String, dynamic> json) =>
      DocumentoBiblioteca(
        hash: json['hash'] as String,
        nome: json['nome'] as String,
        caminhoArquivo: json['caminhoArquivo'] as String,
        recebidoEm: DateTime.parse(json['recebidoEm'] as String),
        enviadoPara:
            (json['enviadoPara'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            const [],
      );
}
