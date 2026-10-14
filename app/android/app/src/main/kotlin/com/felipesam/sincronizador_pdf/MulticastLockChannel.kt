package com.felipesam.sincronizador_pdf

import android.content.Context
import android.net.wifi.WifiManager
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

private const val NOME_CANAL = "sincronizador_pdf/multicast_lock"
private const val TAG_LOCK = "sincronizador_pdf_mdns"

/**
 * Expõe ao lado Dart (ver `lib/sync/multicast_lock.dart`) o multicast lock
 * do Android (`WifiManager.MulticastLock`), exigido para receber pacotes
 * mDNS durante a busca do Backend de Sincronização na rede local
 * (ver #27, #28, #29).
 *
 * O lock é *reference-counted*: múltiplas chamadas a "adquirir" exigem o
 * mesmo número de chamadas a "liberar" antes de ser efetivamente liberado,
 * permitindo buscas concorrentes sem uma liberar o lock da outra antes da
 * hora.
 */
class MulticastLockChannel(context: Context) {
    private val lock: WifiManager.MulticastLock by lazy {
        val wifiManager =
            context.applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
        wifiManager.createMulticastLock(TAG_LOCK).apply { setReferenceCounted(true) }
    }

    fun registrar(flutterEngine: FlutterEngine) {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, NOME_CANAL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "adquirir" -> {
                        lock.acquire()
                        result.success(null)
                    }
                    "liberar" -> {
                        // Tolera uma chamada "liberar" sem "adquirir" correspondente
                        // (ex: hot reload reiniciando o lado Dart no meio de uma busca)
                        // em vez de derrubar o app com RuntimeException.
                        if (lock.isHeld) lock.release()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
