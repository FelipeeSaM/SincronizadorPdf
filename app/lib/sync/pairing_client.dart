/// Código de Pareamento recém-gerado pelo Backend de Sincronização, a ser
/// exibido como QR code pelo Dispositivo de origem.
class CodigoPareamento {
  const CodigoPareamento({required this.codigo, required this.expiraEm});

  final String codigo;
  final DateTime expiraEm;
}

/// Situação de um código de Pareamento, consultada pelo Dispositivo que o
/// gerou enquanto aguarda o outro Dispositivo escanear e confirmar.
enum StatusCodigoPareamento { pendente, confirmado, expirado }

/// Resultado de uma consulta de status de um código de Pareamento.
class ConsultaStatusPareamento {
  const ConsultaStatusPareamento.pendente()
      : status = StatusCodigoPareamento.pendente,
        outroDispositivoId = null;

  const ConsultaStatusPareamento.expirado()
      : status = StatusCodigoPareamento.expirado,
        outroDispositivoId = null;

  const ConsultaStatusPareamento.confirmado(this.outroDispositivoId)
      : status = StatusCodigoPareamento.confirmado;

  final StatusCodigoPareamento status;

  /// Id do outro Dispositivo pareado, presente apenas quando [status] é
  /// [StatusCodigoPareamento.confirmado].
  final String? outroDispositivoId;
}

/// Resultado de uma confirmação de Pareamento bem-sucedida, do ponto de
/// vista do Dispositivo que escaneou o QR code.
class PareamentoConfirmado {
  const PareamentoConfirmado({required this.outroDispositivoId, required this.pareadoEm});

  final String outroDispositivoId;
  final DateTime pareadoEm;
}

/// Erro de domínio ao confirmar um código de Pareamento, distinto de falhas
/// de rede/transporte.
sealed class ErroConfirmacaoPareamento implements Exception {
  const ErroConfirmacaoPareamento();
}

/// O código informado não corresponde a nenhum código gerado pelo Backend.
class CodigoPareamentoNaoEncontrado extends ErroConfirmacaoPareamento {
  const CodigoPareamentoNaoEncontrado();
}

/// O código existiu, mas expirou ou já foi usado em outro Pareamento.
class CodigoPareamentoInvalido extends ErroConfirmacaoPareamento {
  const CodigoPareamentoInvalido();
}

/// O Dispositivo que está confirmando é o mesmo que gerou o código.
class CodigoPareamentoDoProprioDispositivo extends ErroConfirmacaoPareamento {
  const CodigoPareamentoDoProprioDispositivo();
}

/// Única interface que a UI de Pareamento usa para falar com o Backend de
/// Sincronização, permitindo testar os fluxos de QR com um backend fake.
abstract class PairingClient {
  /// Gera um novo código de Pareamento tendo [dispositivoId] como origem.
  Future<CodigoPareamento> gerarCodigo(String dispositivoId);

  /// Confirma [codigo] a partir de [dispositivoId], vinculando os dois
  /// Dispositivos. Lança [ErroConfirmacaoPareamento] se o código não puder
  /// ser confirmado.
  Future<PareamentoConfirmado> confirmarCodigo(String codigo, String dispositivoId);

  /// Consulta a situação atual de [codigo], usado pelo Dispositivo de
  /// origem para saber quando o outro Dispositivo confirmou o Pareamento.
  Future<ConsultaStatusPareamento> consultarStatus(String codigo);
}
