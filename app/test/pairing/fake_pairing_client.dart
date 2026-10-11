import 'package:sincronizador_pdf/sync/pairing_client.dart';

/// Fake de [PairingClient] para testes de widget dos fluxos de Pareamento,
/// sem depender de rede real.
class FakePairingClient implements PairingClient {
  FakePairingClient({
    CodigoPareamento? codigoGerado,
    this.statusConsultas = const [],
    this.erroAoGerar,
    this.erroAoConfirmar,
  }) : codigoGerado = codigoGerado ?? CodigoPareamento(codigo: 'ABC123', expiraEm: _dataFutura);

  static final _dataFutura = DateTime(2100);

  final CodigoPareamento codigoGerado;
  final Object? erroAoGerar;
  final Object? erroAoConfirmar;

  /// Sequência de respostas devolvidas por chamadas consecutivas a
  /// [consultarStatus] (uma por chamada; a última se repete se houver mais
  /// chamadas do que itens).
  final List<ConsultaStatusPareamento> statusConsultas;
  int _consultaIndex = 0;

  final List<String> codigosConfirmados = [];

  @override
  Future<CodigoPareamento> gerarCodigo(String dispositivoId) async {
    if (erroAoGerar != null) throw erroAoGerar!;
    return codigoGerado;
  }

  @override
  Future<PareamentoConfirmado> confirmarCodigo(String codigo, String dispositivoId) async {
    if (erroAoConfirmar != null) throw erroAoConfirmar!;
    codigosConfirmados.add(codigo);
    return PareamentoConfirmado(outroDispositivoId: 'outro-dispositivo', pareadoEm: _dataFutura);
  }

  @override
  Future<ConsultaStatusPareamento> consultarStatus(String codigo) async {
    if (statusConsultas.isEmpty) {
      return const ConsultaStatusPareamento.pendente();
    }
    final resultado = statusConsultas[_consultaIndex.clamp(0, statusConsultas.length - 1)];
    _consultaIndex++;
    return resultado;
  }
}
