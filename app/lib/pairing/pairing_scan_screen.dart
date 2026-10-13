import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../sync/mdns_pairing_client.dart';
import '../sync/paired_device_store.dart';
import '../sync/pairing_client.dart';

enum _EstadoTela { escaneando, confirmando, confirmado }

/// Tela exibida no celular: usa a câmera para escanear o QR code de
/// Pareamento exibido no PC e confirma o Pareamento, descobrindo o
/// endereço do Backend via mDNS na rede local (ver #27) — sem pedir
/// endereço manual nesta etapa.
class PairingScanScreen extends StatefulWidget {
  const PairingScanScreen({
    super.key,
    required this.dispositivoId,
    this.mdnsPairingClient,
  });

  final String dispositivoId;

  /// Permite injetar um fake nos testes — `null` em produção, quando
  /// [_PairingScanScreenState] usa a implementação real.
  final MdnsPairingClient? mdnsPairingClient;

  @override
  State<PairingScanScreen> createState() => _PairingScanScreenState();
}

class _PairingScanScreenState extends State<PairingScanScreen> {
  final _pairedDeviceStore = const PairedDeviceStore();
  late final _mdnsPairingClient = widget.mdnsPairingClient ?? MdnsPairingClient();

  _EstadoTela _estado = _EstadoTela.escaneando;
  String? _mensagemErro;
  bool _processandoDeteccao = false;

  @override
  void dispose() {
    _mdnsPairingClient.dispose();
    super.dispose();
  }

  Future<void> _aoDetectar(BarcodeCapture captura) async {
    if (_processandoDeteccao) return;

    final barcodes = captura.barcodes;
    final codigo = barcodes.isEmpty ? null : barcodes.first.rawValue;
    if (codigo == null || codigo.isEmpty) return;

    _processandoDeteccao = true;
    setState(() {
      _estado = _EstadoTela.confirmando;
      _mensagemErro = null;
    });

    try {
      final resultado = await _mdnsPairingClient.confirmarCodigo(
        codigo,
        widget.dispositivoId,
      );
      await _pairedDeviceStore.salvar(resultado.outroDispositivoId);
      if (!mounted) return;
      setState(() => _estado = _EstadoTela.confirmado);
    } on NenhumBackendMdnsEncontrado {
      _voltarParaEscanearComErro(
        'Nenhum Backend encontrado na rede. Verifique se o PC está ligado, '
        'com o app aberto, e na mesma rede Wi-Fi.',
      );
    } on CodigoPareamentoNaoEncontrado {
      _voltarParaEscanearComErro('QR code inválido. Tente escanear novamente.');
    } on CodigoPareamentoInvalido {
      _voltarParaEscanearComErro(
        'Este código expirou ou já foi usado. Gere um novo no PC e escaneie de novo.',
      );
    } on CodigoPareamentoDoProprioDispositivo {
      _voltarParaEscanearComErro(
        'Este QR code foi gerado por este mesmo Dispositivo.',
      );
    } catch (_) {
      _voltarParaEscanearComErro(
        'Não foi possível confirmar o Pareamento. Verifique sua conexão e tente novamente.',
      );
    }
  }

  void _voltarParaEscanearComErro(String mensagem) {
    if (!mounted) return;
    setState(() {
      _estado = _EstadoTela.escaneando;
      _mensagemErro = mensagem;
      _processandoDeteccao = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Parear Dispositivo')),
      body: _conteudo(context),
    );
  }

  Widget _conteudo(BuildContext context) {
    switch (_estado) {
      case _EstadoTela.escaneando:
        return Column(
          children: [
            if (_mensagemErro != null)
              Container(
                width: double.infinity,
                color: Theme.of(context).colorScheme.errorContainer,
                padding: const EdgeInsets.all(12),
                child: Text(
                  _mensagemErro!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onErrorContainer,
                  ),
                ),
              ),
            Expanded(child: MobileScanner(onDetect: _aoDetectar)),
          ],
        );

      case _EstadoTela.confirmando:
        return const Center(child: CircularProgressIndicator());

      case _EstadoTela.confirmado:
        return const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 64),
              SizedBox(height: 16),
              Text('Dispositivos pareados com sucesso!'),
            ],
          ),
        );
    }
  }
}
