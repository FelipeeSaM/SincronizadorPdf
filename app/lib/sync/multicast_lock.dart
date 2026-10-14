import 'dart:io';

import 'package:flutter/services.dart';

/// Canal nativo usado para adquirir/liberar o multicast lock do Android
/// (`WifiManager.MulticastLock`) — ver `MainActivity.kt`.
const canalMulticastLock = MethodChannel('sincronizador_pdf/multicast_lock');

/// Garante que o multicast lock do Android esteja adquirido durante cada
/// busca mDNS do Backend de Sincronização na rede local (ver #27, #28) —
/// sem ele, o Android descarta os pacotes multicast recebidos.
///
/// Fora do Android (ver [MulticastLock.paraPlataforma]) não existe esse
/// conceito, então [MulticastLock.semLock] apenas executa a ação.
abstract class MulticastLock {
  const MulticastLock();

  /// Implementação real, que adquire/libera o lock nativo via
  /// [canalMulticastLock] — o lock do lado Android é *reference-counted*,
  /// então buscas concorrentes podem chamar [comLockAtivo] sem uma liberar
  /// o lock da outra antes da hora.
  factory MulticastLock.android() = _MulticastLockAndroid;

  /// Usada fora do Android, onde não existe o conceito de multicast lock.
  factory MulticastLock.semLock() = _SemMulticastLock;

  /// Implementação apropriada à plataforma atual.
  factory MulticastLock.paraPlataforma() =>
      Platform.isAndroid ? MulticastLock.android() : MulticastLock.semLock();

  /// Executa [acao] com o lock adquirido, garantindo que ele seja liberado
  /// ao final mesmo se [acao] lançar.
  Future<T> comLockAtivo<T>(Future<T> Function() acao);
}

class _MulticastLockAndroid extends MulticastLock {
  const _MulticastLockAndroid();

  @override
  Future<T> comLockAtivo<T>(Future<T> Function() acao) async {
    await canalMulticastLock.invokeMethod('adquirir');
    try {
      return await acao();
    } finally {
      await canalMulticastLock.invokeMethod('liberar');
    }
  }
}

class _SemMulticastLock extends MulticastLock {
  const _SemMulticastLock();

  @override
  Future<T> comLockAtivo<T>(Future<T> Function() acao) => acao();
}
