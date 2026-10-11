import 'dart:async';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../sync/paired_device_store.dart';
import '../sync/pairing_client.dart';

enum _EstadoTela {
  carregando,
  aguardandoConfirmacao,
  confirmado,
  expirado,
  erro,
}

/// Tela exibida no PC: gera um código de Pareamento, mostra-o como QR code
/// e consulta periodicamente o Backend até que o celular o escaneie e
/// confirme o Pareamento.
class PairingCodeScreen extends StatefulWidget {
  const PairingCodeScreen({
    super.key,
    required this.pairingClient,
    required this.dispositivoId,
    this.intervaloConsulta = const Duration(seconds: 2),
  });

  final PairingClient pairingClient;
  final String dispositivoId;
  final Duration intervaloConsulta;

  @override
  State<PairingCodeScreen> createState() => _PairingCodeScreenState();
}

class _PairingCodeScreenState extends State<PairingCodeScreen> {
  final _pairedDeviceStore = const PairedDeviceStore();

  _EstadoTela _estado = _EstadoTela.carregando;
  CodigoPareamento? _codigo;
  Timer? _timer;
  String? _mensagemErro;

  @override
  void initState() {
    super.initState();
    _gerarCodigo();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _gerarCodigo() async {
    setState(() => _estado = _EstadoTela.carregando);
    try {
      final codigo = await widget.pairingClient.gerarCodigo(
        widget.dispositivoId,
      );
      if (!mounted) return;
      setState(() {
        _codigo = codigo;
        _estado = _EstadoTela.aguardandoConfirmacao;
      });
      _timer = Timer.periodic(
        widget.intervaloConsulta,
        (_) => _consultarStatus(codigo.codigo),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _estado = _EstadoTela.erro;
        _mensagemErro =
            'Não foi possível gerar o código de Pareamento. Verifique o endereço do Backend e tente novamente.';
      });
    }
  }

  Future<void> _consultarStatus(String codigo) async {
    try {
      final resultado = await widget.pairingClient.consultarStatus(codigo);
      if (!mounted) return;
      switch (resultado.status) {
        case StatusCodigoPareamento.pendente:
          return;
        case StatusCodigoPareamento.confirmado:
          _timer?.cancel();
          await _pairedDeviceStore.salvar(resultado.outroDispositivoId!);
          if (!mounted) return;
          setState(() => _estado = _EstadoTela.confirmado);
        case StatusCodigoPareamento.expirado:
          _timer?.cancel();
          setState(() => _estado = _EstadoTela.expirado);
      }
    } catch (_) {
      // Falha pontual de rede na consulta periódica: tenta de novo no próximo tick.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Parear Dispositivo')),
      body: Center(child: _conteudo(context)),
    );
  }

  Widget _conteudo(BuildContext context) {
    switch (_estado) {
      case _EstadoTela.carregando:
        return const CircularProgressIndicator();

      case _EstadoTela.aguardandoConfirmacao:
        final codigo = _codigo!;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Escaneie este QR code no celular para parear os Dispositivos',
            ),
            const SizedBox(height: 24),
            QrImageView(data: codigo.codigo, size: 240),
            const SizedBox(height: 24),
            Text(
              codigo.codigo,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            const CircularProgressIndicator(),
          ],
        );

      case _EstadoTela.confirmado:
        return const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 64),
            SizedBox(height: 16),
            Text('Dispositivos pareados com sucesso!'),
          ],
        );

      case _EstadoTela.expirado:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 64),
            const SizedBox(height: 16),
            const Text('O código expirou antes de ser confirmado.'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _gerarCodigo,
              child: const Text('Gerar novo código'),
            ),
          ],
        );

      case _EstadoTela.erro:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 64),
            const SizedBox(height: 16),
            Text(_mensagemErro ?? 'Ocorreu um erro inesperado.'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _gerarCodigo,
              child: const Text('Tentar novamente'),
            ),
          ],
        );
    }
  }
}
