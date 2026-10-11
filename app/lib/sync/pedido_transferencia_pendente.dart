/// Um pedido de Transferência de Documento ainda não aceito pelo Backend
/// de Sincronização, retido na Fila Local de Sincronização (ver ADR-0005).
///
/// Não guarda os bytes do Documento — eles já estão na Biblioteca local
/// sob [hash], de onde são lidos no momento do reenvio.
class PedidoTransferenciaPendente {
  const PedidoTransferenciaPendente({
    required this.hash,
    required this.destinoDispositivoId,
    required this.criadoEm,
  });

  final String hash;
  final String destinoDispositivoId;
  final DateTime criadoEm;

  Map<String, dynamic> toJson() => {
    'hash': hash,
    'destinoDispositivoId': destinoDispositivoId,
    'criadoEm': criadoEm.toIso8601String(),
  };

  factory PedidoTransferenciaPendente.fromJson(Map<String, dynamic> json) =>
      PedidoTransferenciaPendente(
        hash: json['hash'] as String,
        destinoDispositivoId: json['destinoDispositivoId'] as String,
        criadoEm: DateTime.parse(json['criadoEm'] as String),
      );
}
