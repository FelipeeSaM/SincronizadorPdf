import 'package:flutter/material.dart';

import 'home_screen.dart';
import 'theme_mode_store.dart';

void main() {
  runApp(const SincronizadorPdfApp());
}

class SincronizadorPdfApp extends StatefulWidget {
  const SincronizadorPdfApp({super.key});

  @override
  State<SincronizadorPdfApp> createState() => _SincronizadorPdfAppState();
}

class _SincronizadorPdfAppState extends State<SincronizadorPdfApp> {
  final _themeModeStore = const ThemeModeStore();
  final _temaAtual = ValueNotifier(ThemeMode.system);

  @override
  void initState() {
    super.initState();
    _carregarTemaSalvo();
  }

  Future<void> _carregarTemaSalvo() async {
    _temaAtual.value = await _themeModeStore.obter();
  }

  Future<void> _selecionarTema(ThemeMode tema) async {
    _temaAtual.value = tema;
    await _themeModeStore.salvar(tema);
  }

  @override
  void dispose() {
    _temaAtual.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: _temaAtual,
      builder: (context, temaAtual, _) {
        return MaterialApp(
          title: 'Sincronizador PDF',
          theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple)),
          darkTheme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.deepPurple,
              brightness: Brightness.dark,
            ),
          ),
          themeMode: temaAtual,
          home: HomeScreen(
            temaAtual: temaAtual,
            onSelecionarTema: _selecionarTema,
          ),
        );
      },
    );
  }
}
