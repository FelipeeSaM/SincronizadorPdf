import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Guarda e recupera a preferência de tema (claro/escuro/sistema) escolhida
/// pelo usuário, para o app reabrir já nela em vez de sempre cair no tema do
/// sistema operacional.
class ThemeModeStore {
  const ThemeModeStore();

  static const _chave = 'theme_mode';

  Future<ThemeMode> obter() async {
    final prefs = await SharedPreferences.getInstance();
    final nomeSalvo = prefs.getString(_chave);
    return ThemeMode.values.firstWhere(
      (tema) => tema.name == nomeSalvo,
      orElse: () => ThemeMode.system,
    );
  }

  Future<void> salvar(ThemeMode tema) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_chave, tema.name);
  }
}
