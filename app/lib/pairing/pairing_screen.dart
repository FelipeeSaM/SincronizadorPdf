import 'dart:io';

import 'package:flutter/material.dart';

import '../sync/backend_url_store.dart';
import '../sync/device_id_store.dart';
import '../sync/http_pairing_client.dart';
import 'pairing_code_screen.dart';
import 'pairing_scan_screen.dart';

/// Tela de Pareamento: no PC (desktop), gera e exibe um QR code; no celular
/// (Android), escaneia esse QR e confirma o Pareamento descobrindo o
/// Backend via mDNS na rede local (ver #27) — sem pedir endereço manual
/// nesse caso.
///
/// No PC, quando há um Backend local disponível (ver #24), usa
/// `http://localhost:<porta>` automaticamente e pula a tela manual de
/// endereço. Sem ele (ex: o Backend local não iniciou), pede o endereço
/// onde o Backend está hospedado como fallback — não há descoberta
/// automática de um Backend remoto, pois é auto-hospedado (ver ADR-0003,
/// #26).
class PairingScreen extends StatefulWidget {
  const PairingScreen({super.key, this.enderecoBackendLocal});

  /// `http://localhost:<porta>` do Backend local (ver #24), ou `null` em
  /// plataformas sem Backend local ou se ele não iniciou.
  final Future<String?>? enderecoBackendLocal;

  @override
  State<PairingScreen> createState() => _PairingScreenState();
}

class _PairingScreenState extends State<PairingScreen> {
  final _deviceIdStore = const DeviceIdStore();
  final _backendUrlStore = const BackendUrlStore();
  final _urlController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  String? _dispositivoId;
  bool _urlConfirmada = false;

  static bool get _ehDispositivoMovel => Platform.isAndroid || Platform.isIOS;

  @override
  void initState() {
    super.initState();
    _carregarEstadoInicial();
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _carregarEstadoInicial() async {
    // Disparado antes de aguardar o endereço do Backend — que, no PC, pode
    // demorar até o timeout do `BackendProcessManager` (10s) se o Backend
    // local estiver lento para subir (ver #24) — para não atrasar também
    // essa leitura local independente.
    final dispositivoIdFuture = _deviceIdStore.obterOuCriar();

    if (_ehDispositivoMovel) {
      // No celular, o endereço do Backend é descoberto via mDNS a cada
      // Pareamento (ver #27) — não há URL manual nem guardada para pedir
      // aqui.
      final dispositivoId = await dispositivoIdFuture;
      if (!mounted) return;
      setState(() => _dispositivoId = dispositivoId);
      return;
    }

    final enderecoBackendLocal = await widget.enderecoBackendLocal;
    final dispositivoId = await dispositivoIdFuture;

    if (enderecoBackendLocal != null) {
      // Backend local disponível: pula a tela manual de endereço — só faz
      // sentido pedi-lo quando não há Backend próprio rodando (ver #26).
      if (!mounted) return;
      setState(() {
        _dispositivoId = dispositivoId;
        _urlController.text = enderecoBackendLocal;
        _urlConfirmada = true;
      });
      return;
    }

    final urlSalva = await _backendUrlStore.obter();

    if (!mounted) return;
    setState(() {
      _dispositivoId = dispositivoId;
      if (urlSalva != null) {
        _urlController.text = urlSalva;
      }
    });
  }

  Future<void> _confirmarUrl() async {
    if (!_formKey.currentState!.validate()) return;

    await _backendUrlStore.salvar(_urlController.text.trim());

    if (!mounted) return;
    setState(() => _urlConfirmada = true);
  }

  @override
  Widget build(BuildContext context) {
    final dispositivoId = _dispositivoId;
    if (dispositivoId == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_ehDispositivoMovel) {
      return PairingScanScreen(dispositivoId: dispositivoId);
    }

    if (!_urlConfirmada) {
      return Scaffold(
        appBar: AppBar(title: const Text('Parear Dispositivo')),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Endereço do Backend de Sincronização'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _urlController,
                  decoration: const InputDecoration(
                    hintText: 'https://meu-backend.exemplo.com',
                  ),
                  keyboardType: TextInputType.url,
                  validator: validarUrlBackendObrigatoria,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _confirmarUrl,
                  child: const Text('Continuar'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final pairingClient = HttpPairingClient(
      baseUrl: _urlController.text.trim(),
    );

    return PairingCodeScreen(
      pairingClient: pairingClient,
      dispositivoId: dispositivoId,
    );
  }
}
