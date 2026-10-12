import 'package:flutter_test/flutter_test.dart';
import 'package:sincronizador_pdf/sync/highlight.dart';

void main() {
  test('HighlightRect sobrevive a um ciclo de toJson/fromJson', () {
    const rect = HighlightRect(left: 10, top: 90, right: 80, bottom: 70);

    final reconstruido = HighlightRect.fromJson(rect.toJson());

    expect(reconstruido.left, 10);
    expect(reconstruido.top, 90);
    expect(reconstruido.right, 80);
    expect(reconstruido.bottom, 70);
  });

  test('Highlight sobrevive a um ciclo de toJson/fromJson', () {
    final highlight = Highlight(
      localId: 'local-1',
      remoteId: 'remoto-1',
      page: 3,
      rects: const [HighlightRect(left: 0, top: 10, right: 20, bottom: 0)],
      trechoTexto: 'trecho selecionado',
      criadoEm: DateTime.utc(2026, 1, 1, 12),
    );

    final reconstruido = Highlight.fromJson(highlight.toJson());

    expect(reconstruido.localId, 'local-1');
    expect(reconstruido.remoteId, 'remoto-1');
    expect(reconstruido.page, 3);
    expect(reconstruido.rects.single.right, 20);
    expect(reconstruido.trechoTexto, 'trecho selecionado');
    expect(reconstruido.criadoEm, DateTime.utc(2026, 1, 1, 12));
  });

  test('Highlight sem remoteId nem trechoTexto sobrevive ao ciclo', () {
    final highlight = Highlight(
      localId: 'local-2',
      page: 1,
      rects: const [],
      criadoEm: DateTime.utc(2026, 1, 1),
    );

    final reconstruido = Highlight.fromJson(highlight.toJson());

    expect(reconstruido.remoteId, isNull);
    expect(reconstruido.trechoTexto, isNull);
    expect(reconstruido.rects, isEmpty);
  });

  test('comRemoteId preserva os demais campos e troca só o remoteId', () {
    final highlight = Highlight(
      localId: 'local-3',
      page: 2,
      rects: const [HighlightRect(left: 0, top: 0, right: 0, bottom: 0)],
      trechoTexto: 'abc',
      criadoEm: DateTime.utc(2026, 1, 1),
    );

    final confirmado = highlight.comRemoteId('remoto-3');

    expect(confirmado.remoteId, 'remoto-3');
    expect(confirmado.localId, highlight.localId);
    expect(confirmado.page, highlight.page);
    expect(confirmado.trechoTexto, highlight.trechoTexto);
    expect(confirmado.criadoEm, highlight.criadoEm);
  });
}
