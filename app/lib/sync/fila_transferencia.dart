import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'diretorio_app.dart';
import 'pedido_transferencia_pendente.dart';

/// Fila Local de Sincronização (ver ADR-0005) dos pedidos de Transferência
/// de Documento ainda não aceitos pelo Backend de Sincronização — retidos
/// aqui quando o envio falha (ex: Backend fora do ar) e reenviados até
/// confirmação, com o app em foco.
class FilaTransferencia {
  FilaTransferencia({Future<Directory> Function()? diretorioBase})
    : _diretorioBase = diretorioBase ?? getApplicationSupportDirectory;

  final Future<Directory> Function() _diretorioBase;

  Future<File> _arquivoFila() async {
    final dir = await diretorioComSubpasta(
      _diretorioBase,
      'fila-transferencia',
    );
    return File(p.join(dir.path, 'pendentes.json'));
  }

  Future<List<PedidoTransferenciaPendente>> listar() async {
    final arquivo = await _arquivoFila();
    if (!await arquivo.exists()) return [];

    final conteudo = await arquivo.readAsString();
    if (conteudo.trim().isEmpty) return [];

    final lista = jsonDecode(conteudo) as List<dynamic>;
    return lista
        .map(
          (item) => PedidoTransferenciaPendente.fromJson(
            item as Map<String, dynamic>,
          ),
        )
        .toList();
  }

  Future<void> _salvar(List<PedidoTransferenciaPendente> pedidos) async {
    final arquivo = await _arquivoFila();
    await arquivo.writeAsString(
      jsonEncode(pedidos.map((pedido) => pedido.toJson()).toList()),
    );
  }

  /// Retém [pedido] na fila. Um pedido já enfileirado para o mesmo
  /// (hash, Dispositivo de destino) não gera entrada duplicada.
  Future<void> enfileirar(PedidoTransferenciaPendente pedido) async {
    final pedidos = await listar();
    final jaEnfileirado = pedidos.any(
      (p) =>
          p.hash == pedido.hash &&
          p.destinoDispositivoId == pedido.destinoDispositivoId,
    );
    if (jaEnfileirado) return;

    pedidos.add(pedido);
    await _salvar(pedidos);
  }

  Future<void> remover(PedidoTransferenciaPendente pedido) async {
    final pedidos = await listar();
    pedidos.removeWhere(
      (p) =>
          p.hash == pedido.hash &&
          p.destinoDispositivoId == pedido.destinoDispositivoId,
    );
    await _salvar(pedidos);
  }

  /// Remove todos os pedidos pendentes de [hash], para qualquer Dispositivo
  /// de destino — usado ao excluir o Documento da Biblioteca local (ver
  /// #20): não faz sentido continuar tentando enviar um Documento que o
  /// próprio usuário acabou de apagar.
  Future<void> removerPorHash(String hash) async {
    final pedidos = await listar();
    pedidos.removeWhere((p) => p.hash == hash);
    await _salvar(pedidos);
  }
}
