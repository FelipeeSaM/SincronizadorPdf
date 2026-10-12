import 'dart:convert';

import 'package:http/http.dart' as http;

import 'highlight.dart';
import 'highlight_client.dart';

/// Implementação de [HighlightClient] que fala com o Backend de
/// Sincronização (.NET) via HTTP, contra os endpoints expostos em
/// `/highlights`. Os retângulos de [Highlight.rects] são transportados
/// codificados em JSON dentro do campo `coordenadas` (string), que o
/// Backend guarda como metadado opaco, sem interpretá-lo (ADR-0001).
class HttpHighlightClient implements HighlightClient {
  HttpHighlightClient({required String baseUrl, http.Client? httpClient})
    : _baseUrl = baseUrl.endsWith('/')
          ? baseUrl.substring(0, baseUrl.length - 1)
          : baseUrl,
      _http = httpClient ?? http.Client();

  final String _baseUrl;
  final http.Client _http;

  @override
  Future<String> criar({
    required String hash,
    required int page,
    required List<HighlightRect> rects,
    String? trechoTexto,
  }) async {
    final response = await _http.post(
      Uri.parse('$_baseUrl/highlights'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'hash': hash,
        'page': page,
        'coordenadas': _codificarRects(rects),
        'trechoTexto': trechoTexto,
      }),
    );

    if (response.statusCode != 201) {
      throw Exception('Falha ao criar Highlight: HTTP ${response.statusCode}');
    }

    final corpo = jsonDecode(response.body) as Map<String, dynamic>;
    return corpo['id'] as String;
  }

  @override
  Future<List<Highlight>> listar(String hash) async {
    final response = await _http.get(
      Uri.parse('$_baseUrl/highlights?hash=$hash'),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Falha ao listar Highlights: HTTP ${response.statusCode}',
      );
    }

    final corpo = jsonDecode(response.body) as List<dynamic>;
    return corpo
        .map((item) => _fromBackendJson(item as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<void> apagar(String remoteId) async {
    final response = await _http.delete(
      Uri.parse('$_baseUrl/highlights/$remoteId'),
    );

    // 404 é tratado como sucesso: o Highlight já não existe no Backend, que
    // é exatamente o estado desejado por uma remoção (idempotente).
    if (response.statusCode != 204 && response.statusCode != 404) {
      throw Exception('Falha ao apagar Highlight: HTTP ${response.statusCode}');
    }
  }

  String _codificarRects(List<HighlightRect> rects) =>
      jsonEncode(rects.map((r) => r.toJson()).toList());

  List<HighlightRect> _decodificarRects(String coordenadas) =>
      (jsonDecode(coordenadas) as List<dynamic>)
          .map((r) => HighlightRect.fromJson(r as Map<String, dynamic>))
          .toList();

  Highlight _fromBackendJson(Map<String, dynamic> json) {
    final id = json['id'] as String;
    return Highlight(
      localId: id,
      remoteId: id,
      page: json['page'] as int,
      rects: _decodificarRects(json['coordenadas'] as String),
      trechoTexto: json['trechoTexto'] as String?,
      criadoEm: DateTime.parse(json['createdAt'] as String),
    );
  }
}
