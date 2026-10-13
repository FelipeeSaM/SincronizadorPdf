import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Assina a função usada para iniciar o processo filho do Backend — permite
/// substituir [Process.start] por um fake nos testes (ver #24).
typedef IniciadorDeProcesso =
    Future<Process> Function(
      String executavel,
      List<String> argumentos, {
      Map<String, String>? environment,
      String? workingDirectory,
    });

/// Prefixo da linha que o Backend de Sincronização escreve no próprio
/// stdout, em modo LAN, para reportar a porta efetiva em que ficou
/// disponível (porta padrão ou, se ocupada, uma porta livre do SO — ver
/// `LanModePortSelector` no backend).
const prefixoPortaBackend = 'SINCRONIZADOR_PDF_PORT=';

/// Lançada quando o processo do Backend encerra antes de reportar a porta
/// (ver #24) — sinal de falha ao iniciar (ex: build quebrado, runtime
/// ausente, porta não pôde ser aberta), bem diferente de um timeout
/// genérico por estar simplesmente lento.
class BackendEncerrouAntesDaPorta implements Exception {
  const BackendEncerrouAntesDaPorta(this.codigoSaida);

  final int codigoSaida;

  @override
  String toString() =>
      'BackendEncerrouAntesDaPorta: processo encerrou com código '
      '$codigoSaida antes de reportar a porta';
}

/// Controla o ciclo de vida do processo do Backend de Sincronização como
/// filho do app desktop: nasce quando o app abre, morre quando o app fecha
/// — nunca um serviço sempre ativo no PC (trade-off aceito em #24).
class BackendProcessManager {
  BackendProcessManager({
    required this.executavel,
    required this.argumentos,
    this.environment,
    this.workingDirectory,
    IniciadorDeProcesso? iniciadorDeProcesso,
    Duration? timeoutPorta,
  }) : _iniciarProcesso = iniciadorDeProcesso ?? Process.start,
       _timeoutPorta = timeoutPorta ?? const Duration(seconds: 10);

  final String executavel;
  final List<String> argumentos;
  final Map<String, String>? environment;

  /// Diretório de trabalho do processo filho — define onde o Backend
  /// resolve seus bancos SQLite relativos (`ContentRootPath`). Sem isso, o
  /// Backend herdaria o diretório de trabalho do app desktop, espalhando
  /// os bancos num lugar imprevisível (ver #24).
  final String? workingDirectory;
  final IniciadorDeProcesso _iniciarProcesso;
  final Duration _timeoutPorta;

  Process? _processo;
  int? _porta;

  /// A porta em que o Backend ficou disponível depois de [iniciar]
  /// completar — `null` antes disso ou depois de [encerrar].
  int? get porta => _porta;

  /// Inicia o processo filho e aguarda a porta efetiva anunciada no stdout
  /// (ver [prefixoPortaBackend]). Lança [TimeoutException] se o Backend
  /// ficar sem reportar a porta até o timeout, ou
  /// [BackendEncerrouAntesDaPorta] se o processo morrer antes disso (ex:
  /// falha ao iniciar) — sem essa corrida contra [Process.exitCode],
  /// esperaríamos o timeout inteiro por um processo que já morreu.
  ///
  /// Continua drenando stdout/stderr depois de encontrar a porta — sem
  /// isso, o Backend (que loga continuamente no console) bloquearia
  /// esperando o buffer do pipe esvaziar.
  Future<int> iniciar() async {
    final processo = await _iniciarProcesso(
      executavel,
      argumentos,
      environment: environment,
      workingDirectory: workingDirectory,
    );
    _processo = processo;

    final portaCompleter = Completer<int>();
    processo.stdout.transform(utf8.decoder).transform(const LineSplitter()).listen((
      linha,
    ) {
      if (!portaCompleter.isCompleted &&
          linha.startsWith(prefixoPortaBackend)) {
        portaCompleter.complete(
          int.parse(linha.substring(prefixoPortaBackend.length)),
        );
      }
    });
    processo.stderr.transform(utf8.decoder).listen((_) {});

    unawaited(
      processo.exitCode.then((codigoSaida) {
        if (!portaCompleter.isCompleted) {
          portaCompleter.completeError(
            BackendEncerrouAntesDaPorta(codigoSaida),
          );
        }
      }),
    );

    _porta = await portaCompleter.future.timeout(_timeoutPorta);
    return _porta!;
  }

  /// Encerra o processo do Backend, se estiver em execução — chamado ao
  /// fechar o app (ver #24), para nunca deixá-lo como processo órfão.
  void encerrar() {
    _processo?.kill();
    _processo = null;
    _porta = null;
  }
}
