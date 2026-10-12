import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sincronizador_pdf/theme_mode_store.dart';

void main() {
  late ThemeModeStore store;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    store = const ThemeModeStore();
  });

  test('sem preferência salva retorna ThemeMode.system por padrão', () async {
    expect(await store.obter(), ThemeMode.system);
  });

  test('salvar e obter fazem o ciclo completo para cada tema', () async {
    for (final tema in ThemeMode.values) {
      await store.salvar(tema);
      expect(await store.obter(), tema);
    }
  });
}
