import 'dart:convert';

import 'package:http/http.dart' as http;

import 'posicao_leitura.dart';
import 'reading_position_client.dart';

/// Implementação de [ReadingPositionClient] que fala com o Backend de
/// Sincronização (.NET) via HTTP, contra os endpoints expostos em
/// `/posicoes-leitura`.
class HttpReadingPositionClient implements ReadingPositionClient {
  HttpReadingPositionClient({required String baseUrl, http.Client? httpClient})
    : _baseUrl = baseUrl.endsWith('/')
          ? baseUrl.substring(0, baseUrl.length - 1)
          : baseUrl,
      _http = httpClient ?? http.Client();

  final String _baseUrl;
  final http.Client _http;

  @override
  Future<PosicaoLeitura> definir({
    required String hash,
    required String deviceId,
    required int pagina,
    required double percentualRolagem,
    required DateTime atualizadoEm,
  }) async {
    final response = await _http.put(
      Uri.parse('$_baseUrl/posicoes-leitura/$hash'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'deviceId': deviceId,
        'page': pagina,
        'scrollPercentage': percentualRolagem,
        'updatedAt': atualizadoEm.toUtc().toIso8601String(),
      }),
    );

    switch (response.statusCode) {
      case 204:
        // Aceita: a própria Posição de Leitura enviada venceu.
        return PosicaoLeitura(
          pagina: pagina,
          percentualRolagem: percentualRolagem,
          atualizadoEm: atualizadoEm,
        );
      case 200:
        // Rejeitada por ser mais antiga (ADR-0005): o corpo traz a vencedora atual.
        return _fromBackendJson(jsonDecode(response.body) as Map<String, dynamic>);
      default:
        throw Exception(
          'Falha ao definir Posição de Leitura: HTTP ${response.statusCode}',
        );
    }
  }

  @override
  Future<PosicaoLeitura?> obter(String hash) async {
    final response = await _http.get(
      Uri.parse('$_baseUrl/posicoes-leitura/$hash'),
    );

    if (response.statusCode == 404) return null;
    if (response.statusCode != 200) {
      throw Exception(
        'Falha ao obter Posição de Leitura: HTTP ${response.statusCode}',
      );
    }

    return _fromBackendJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  PosicaoLeitura _fromBackendJson(Map<String, dynamic> json) => PosicaoLeitura(
    pagina: json['page'] as int,
    percentualRolagem: (json['scrollPercentage'] as num).toDouble(),
    atualizadoEm: DateTime.parse(json['updatedAt'] as String),
  );
}
