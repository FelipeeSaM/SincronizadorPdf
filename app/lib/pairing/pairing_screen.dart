import 'dart:io';

import 'package:flutter/material.dart';

import '../sync/backend_url_store.dart';
import '../sync/device_id_store.dart';
import '../sync/http_pairing_client.dart';
import 'pairing_code_screen.dart';
import 'pairing_scan_screen.dart';

/// Tela de Pareamento: no PC (desktop), gera e exibe um QR code; no celular
/// (Android), escaneia esse QR e confirma o Pareamento.
///
/// Antes de falar com o Backend de Sincronização, pede o endereço onde ele
/// está hospedado — não há descoberta automática, pois é auto-hospedado
/// (ver ADR-0003).
class PairingScreen extends StatefulWidget {
  const PairingScreen({super.key});

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
    final dispositivoId = await _deviceIdStore.obterOuCriar();
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
                  validator: (valor) => (valor == null || valor.trim().isEmpty)
                      ? 'Informe o endereço do Backend'
                      : null,
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
    final ehDispositivoMovel = Platform.isAndroid || Platform.isIOS;

    return ehDispositivoMovel
        ? PairingScanScreen(
            pairingClient: pairingClient,
            dispositivoId: dispositivoId,
          )
        : PairingCodeScreen(
            pairingClient: pairingClient,
            dispositivoId: dispositivoId,
          );
  }
}
