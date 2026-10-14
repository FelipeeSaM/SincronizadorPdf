import 'package:flutter_test/flutter_test.dart';
import 'package:sincronizador_pdf/sync/mdns_backend_browser.dart';

void main() {
  group('extrairDispositivoIdDoTxt', () {
    test('extrai o valor quando há só a propriedade dispositivoId', () {
      expect(extrairDispositivoIdDoTxt('dispositivoId=abc-123'), 'abc-123');
    });

    test('extrai o valor quando há outras propriedades em outras linhas', () {
      expect(
        extrairDispositivoIdDoTxt('outraPropriedade=valor\ndispositivoId=abc-123\nmais=coisa'),
        'abc-123',
      );
    });

    test('retorna null quando não há a propriedade dispositivoId', () {
      expect(extrairDispositivoIdDoTxt('outraPropriedade=valor'), isNull);
    });

    test('retorna null para texto vazio', () {
      expect(extrairDispositivoIdDoTxt(''), isNull);
    });
  });

  group('BackendMdns', () {
    test('backends com o mesmo baseUrl e dispositivoId são iguais', () {
      const a = BackendMdns(baseUrl: 'http://192.168.1.10:5119', dispositivoId: 'pc-1');
      const b = BackendMdns(baseUrl: 'http://192.168.1.10:5119', dispositivoId: 'pc-1');

      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('backends com dispositivoId diferente não são iguais', () {
      const a = BackendMdns(baseUrl: 'http://192.168.1.10:5119', dispositivoId: 'pc-1');
      const b = BackendMdns(baseUrl: 'http://192.168.1.10:5119', dispositivoId: 'pc-2');

      expect(a == b, isFalse);
    });
  });
}
