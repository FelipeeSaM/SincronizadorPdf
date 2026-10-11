import 'dart:convert';

import 'package:http/http.dart' as http;

import 'pairing_client.dart';

/// Implementação de [PairingClient] que fala com o Backend de Sincronização
/// (.NET) via HTTP, contra os endpoints expostos em `/pareamento`.
class HttpPairingClient implements PairingClient {
  HttpPairingClient({required String baseUrl, http.Client? httpClient})
      : _baseUrl = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl,
        _http = httpClient ?? http.Client();

  final String _baseUrl;
  final http.Client _http;

  @override
  Future<CodigoPareamento> gerarCodigo(String dispositivoId) async {
    final response = await _http.post(
      Uri.parse('$_baseUrl/pareamento/codigos'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({'deviceId': dispositivoId}),
    );

    if (response.statusCode != 201) {
      throw Exception('Falha ao gerar código de Pareamento: HTTP ${response.statusCode}');
    }

    final corpo = jsonDecode(response.body) as Map<String, dynamic>;
    return CodigoPareamento(
      codigo: corpo['code'] as String,
      expiraEm: DateTime.parse(corpo['expiresAt'] as String),
    );
  }

  @override
  Future<PareamentoConfirmado> confirmarCodigo(String codigo, String dispositivoId) async {
    final response = await _http.post(
      Uri.parse('$_baseUrl/pareamento/codigos/$codigo/confirmacoes'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({'deviceId': dispositivoId}),
    );

    switch (response.statusCode) {
      case 200:
        final corpo = jsonDecode(response.body) as Map<String, dynamic>;
        return PareamentoConfirmado(
          outroDispositivoId: corpo['deviceAId'] as String,
          pareadoEm: DateTime.parse(corpo['pairedAt'] as String),
        );
      case 404:
        throw const CodigoPareamentoNaoEncontrado();
      case 410:
        throw const CodigoPareamentoInvalido();
      case 400:
        throw const CodigoPareamentoDoProprioDispositivo();
      default:
        throw Exception('Falha ao confirmar código de Pareamento: HTTP ${response.statusCode}');
    }
  }

  @override
  Future<ConsultaStatusPareamento> consultarStatus(String codigo) async {
    final response = await _http.get(Uri.parse('$_baseUrl/pareamento/codigos/$codigo'));

    if (response.statusCode == 404) {
      throw const CodigoPareamentoNaoEncontrado();
    }
    if (response.statusCode != 200) {
      throw Exception('Falha ao consultar status do Pareamento: HTTP ${response.statusCode}');
    }

    final corpo = jsonDecode(response.body) as Map<String, dynamic>;
    switch (corpo['status'] as String) {
      case 'pendente':
        return const ConsultaStatusPareamento.pendente();
      case 'expirado':
        return const ConsultaStatusPareamento.expirado();
      case 'confirmado':
        return ConsultaStatusPareamento.confirmado(corpo['deviceBId'] as String);
      default:
        throw Exception('Status de Pareamento desconhecido: ${corpo['status']}');
    }
  }
}
