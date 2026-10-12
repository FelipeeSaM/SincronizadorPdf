import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'transfer_client.dart';

/// Implementação de [TransferClient] que fala com o Backend de Sincronização
/// (.NET) via HTTP, contra os endpoints expostos em `/transferencias`.
class HttpTransferClient implements TransferClient {
  HttpTransferClient({required String baseUrl, http.Client? httpClient})
    : _baseUrl = baseUrl.endsWith('/')
          ? baseUrl.substring(0, baseUrl.length - 1)
          : baseUrl,
      _http = httpClient ?? http.Client();

  final String _baseUrl;
  final http.Client _http;

  @override
  Future<String> enviar({
    required String origemDispositivoId,
    required String destinoDispositivoId,
    required Uint8List conteudo,
    required String nome,
  }) async {
    final response = await _http.post(
      Uri.parse(
        '$_baseUrl/transferencias?originDeviceId=$origemDispositivoId&targetDeviceId=$destinoDispositivoId&fileName=${Uri.encodeQueryComponent(nome)}',
      ),
      headers: const {'Content-Type': 'application/octet-stream'},
      body: conteudo,
    );

    if (response.statusCode == 403) {
      throw const DispositivosNaoPareados();
    }
    if (response.statusCode != 201) {
      throw Exception('Falha ao enviar Documento: HTTP ${response.statusCode}');
    }

    final corpo = jsonDecode(response.body) as Map<String, dynamic>;
    return corpo['hash'] as String;
  }

  @override
  Future<List<String>> listarPendentes(String dispositivoId) async {
    final response = await _http.get(
      Uri.parse('$_baseUrl/transferencias?deviceId=$dispositivoId'),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Falha ao listar Transferências pendentes: HTTP ${response.statusCode}',
      );
    }

    final corpo = jsonDecode(response.body) as List<dynamic>;
    return corpo.cast<String>();
  }

  @override
  Future<DocumentoBaixado> baixar({
    required String hash,
    required String dispositivoId,
  }) async {
    final response = await _http.get(
      Uri.parse('$_baseUrl/transferencias/$hash?deviceId=$dispositivoId'),
    );

    if (response.statusCode != 200) {
      throw Exception('Falha ao baixar Documento: HTTP ${response.statusCode}');
    }

    final nomeHeader = response.headers['x-document-name'];
    return (
      conteudo: response.bodyBytes,
      nome: nomeHeader == null ? null : Uri.decodeComponent(nomeHeader),
    );
  }

  @override
  Future<void> confirmarRecebimento({
    required String hash,
    required String dispositivoId,
  }) async {
    final response = await _http.post(
      Uri.parse('$_baseUrl/transferencias/$hash/confirmacoes'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({'deviceId': dispositivoId}),
    );

    if (response.statusCode != 204) {
      throw Exception(
        'Falha ao confirmar recebimento do Documento: HTTP ${response.statusCode}',
      );
    }
  }
}
