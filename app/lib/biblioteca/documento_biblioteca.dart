/// Um Documento cujo arquivo completo já chegou a este Dispositivo,
/// disponível para reabertura na Biblioteca.
class DocumentoBiblioteca {
  const DocumentoBiblioteca({
    required this.hash,
    required this.nome,
    required this.caminhoArquivo,
    required this.recebidoEm,
  });

  final String hash;
  final String nome;
  final String caminhoArquivo;
  final DateTime recebidoEm;

  Map<String, dynamic> toJson() => {
    'hash': hash,
    'nome': nome,
    'caminhoArquivo': caminhoArquivo,
    'recebidoEm': recebidoEm.toIso8601String(),
  };

  factory DocumentoBiblioteca.fromJson(Map<String, dynamic> json) =>
      DocumentoBiblioteca(
        hash: json['hash'] as String,
        nome: json['nome'] as String,
        caminhoArquivo: json['caminhoArquivo'] as String,
        recebidoEm: DateTime.parse(json['recebidoEm'] as String),
      );
}
