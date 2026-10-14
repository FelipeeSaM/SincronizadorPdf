import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Fake de [Process] para testar [BackendProcessManager] sem depender de um
/// processo real do SO (ver #24).
class FakeProcess implements Process {
  FakeProcess({this.pid = 1234});

  @override
  final int pid;

  final List<ProcessSignal> sinaisRecebidos = [];

  final _stdoutController = StreamController<List<int>>();
  final _stderrController = StreamController<List<int>>();
  final _exitCodeCompleter = Completer<int>();

  @override
  Stream<List<int>> get stdout => _stdoutController.stream;

  @override
  Stream<List<int>> get stderr => _stderrController.stream;

  @override
  Future<int> get exitCode => _exitCodeCompleter.future;

  @override
  IOSink get stdin =>
      throw UnsupportedError('stdin não é usado por BackendProcessManager');

  /// Simula uma linha de log (ou a linha de porta) escrita pelo processo.
  void escreverLinhaDeStdout(String linha) {
    _stdoutController.add(utf8.encode('$linha\n'));
  }

  /// Simula o processo morrendo por conta própria (ex: falha ao iniciar),
  /// sem passar por [kill] — para testar a corrida contra
  /// [Process.exitCode] em `BackendProcessManager.iniciar`.
  void simularSaidaInesperada([int codigoSaida = 1]) {
    if (!_exitCodeCompleter.isCompleted) {
      _exitCodeCompleter.complete(codigoSaida);
    }
    unawaited(_stdoutController.close());
    unawaited(_stderrController.close());
  }

  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) {
    sinaisRecebidos.add(signal);
    if (!_exitCodeCompleter.isCompleted) {
      _exitCodeCompleter.complete(-signal.signalNumber);
    }
    unawaited(_stdoutController.close());
    unawaited(_stderrController.close());
    return true;
  }
}
