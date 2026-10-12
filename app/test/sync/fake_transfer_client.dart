import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:sincronizador_pdf/sync/transfer_client.dart';

/// Fake de [TransferClient] para testar [DocumentSyncService] sem rede
/// real, com uma fila de relay em memória equivalente à do Backend
/// (keyed por hash do conteúdo + Dispositivo de destino).
class FakeTransferClient implements TransferClient {
  /// Quando `true`, toda chamada lança exceção — simula o Backend fora do
  /// ar (ver ADR-0005).
  bool indisponivel = false;

  /// Quando `true`, [enviar] lança [DispositivosNaoPareados] — simula
  /// origem e destino sem Pareamento confirmado entre si.
  bool naoPareado = false;

  final Map<String, Map<String, Uint8List>> _pendentesPorDestino = {};
  final Map<String, Map<String, String>> _nomesPorDestino = {};
  final List<String> enviosRecebidos = [];
  final List<String> confirmacoesRecebidas = [];

  @override
  Future<String> enviar({
    required String origemDispositivoId,
    required String destinoDispositivoId,
    required Uint8List conteudo,
    required String nome,
  }) async {
    if (naoPareado) throw const DispositivosNaoPareados();
    if (indisponivel) throw Exception('Backend indisponível');

    final hash = sha256.convert(conteudo).toString();
    _pendentesPorDestino.putIfAbsent(destinoDispositivoId, () => {})[hash] =
        conteudo;
    _nomesPorDestino.putIfAbsent(destinoDispositivoId, () => {})[hash] = nome;
    enviosRecebidos.add(hash);
    return hash;
  }

  @override
  Future<List<String>> listarPendentes(String dispositivoId) async {
    if (indisponivel) throw Exception('Backend indisponível');

    return _pendentesPorDestino[dispositivoId]?.keys.toList() ?? [];
  }

  @override
  Future<DocumentoBaixado> baixar({
    required String hash,
    required String dispositivoId,
  }) async {
    if (indisponivel) throw Exception('Backend indisponível');

    final conteudo = _pendentesPorDestino[dispositivoId]?[hash];
    if (conteudo == null) throw Exception('Transferência não encontrada');
    return (conteudo: conteudo, nome: _nomesPorDestino[dispositivoId]?[hash]);
  }

  @override
  Future<void> confirmarRecebimento({
    required String hash,
    required String dispositivoId,
  }) async {
    if (indisponivel) throw Exception('Backend indisponível');

    _pendentesPorDestino[dispositivoId]?.remove(hash);
    confirmacoesRecebidas.add(hash);
  }

  /// Simula uma Transferência já pendente no Backend, endereçada a
  /// [destinoDispositivoId], sem passar por [enviar]. [nome] é o nome
  /// original propagado pelo Backend (ver #19); `null` simula uma
  /// Transferência sem nome associado.
  void semearPendente({
    required String destinoDispositivoId,
    required Uint8List conteudo,
    String? nome,
  }) {
    final hash = sha256.convert(conteudo).toString();
    _pendentesPorDestino.putIfAbsent(destinoDispositivoId, () => {})[hash] =
        conteudo;
    if (nome != null) {
      _nomesPorDestino.putIfAbsent(destinoDispositivoId, () => {})[hash] =
          nome;
    }
  }
}

String hashDe(Uint8List conteudo) => sha256.convert(conteudo).toString();
