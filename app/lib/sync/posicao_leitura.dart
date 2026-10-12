/// A Posição de Leitura de um Documento (ver CONTEXT.md): o ponto exato em
/// que o usuário parou de ler, como página e percentual de rolagem dentro
/// dela, marcado com o timestamp do Dispositivo que a definiu — é esse
/// timestamp, não o momento de sincronização, que decide o last-write-wins
/// quando os Dispositivos divergem (ADR-0005).
class PosicaoLeitura {
  const PosicaoLeitura({
    required this.pagina,
    required this.percentualRolagem,
    required this.atualizadoEm,
  });

  final int pagina;
  final double percentualRolagem;
  final DateTime atualizadoEm;

  Map<String, dynamic> toJson() => {
    'pagina': pagina,
    'percentualRolagem': percentualRolagem,
    'atualizadoEm': atualizadoEm.toUtc().toIso8601String(),
  };

  factory PosicaoLeitura.fromJson(Map<String, dynamic> json) => PosicaoLeitura(
    pagina: json['pagina'] as int,
    percentualRolagem: (json['percentualRolagem'] as num).toDouble(),
    atualizadoEm: DateTime.parse(json['atualizadoEm'] as String),
  );
}
