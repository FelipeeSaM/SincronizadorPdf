import 'dart:async';
import 'dart:io';
import 'dart:ui' show AppExitResponse;

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import 'home_screen.dart';
import 'sync/backend_dll_resolver.dart';
import 'sync/backend_process_manager.dart';
import 'theme_mode_store.dart';

// Mantidos em variáveis top-level (não locais a `main()`) para que o
// `AppLifecycleListener` não seja coletado pelo GC antes do app fechar —
// ver #24. Nunca lidas de volta: existir já é o efeito que importa.
// ignore: unused_element
BackendProcessManager? _backendProcessManager;
// ignore: unused_element
AppLifecycleListener? _backendLifecycleListener;

void main() {
  if (Platform.isLinux) {
    _iniciarBackendLocal();
  }

  runApp(const SincronizadorPdfApp());
}

/// Inicia o Backend de Sincronização como processo filho do app desktop
/// (Linux) e garante que ele morre junto quando o app fecha — trade-off
/// aceito em #24: sem esse Backend local, o app continua funcionando
/// normalmente, só sem o processo próprio (ex: layout de dev incompleto).
void _iniciarBackendLocal() {
  final caminhoDll = resolverCaminhoBackendDll(
    environment: Platform.environment,
    diretorioAtual: Directory.current,
  );
  if (caminhoDll == null) return;

  final backendProcessManager = BackendProcessManager(
    executavel: 'dotnet',
    argumentos: [caminhoDll],
    environment: const {'SINCRONIZADOR_PDF_LAN_MODE': '1'},
    // Sem isto, o Backend herdaria o diretório de trabalho do app desktop
    // e espalharia os bancos SQLite (ContentRootPath) num lugar
    // imprevisível — ver #24.
    workingDirectory: p.dirname(caminhoDll),
  );
  _backendProcessManager = backendProcessManager;
  unawaited(
    backendProcessManager.iniciar().catchError((Object erro) {
      // O app continua funcionando sem o Backend local (ex: `dotnet` fora
      // do PATH, ou o .dll de dev ainda não foi buildado) — mesma
      // tolerância a Backend indisponível que o resto do app já tem.
      debugPrint('Falha ao iniciar o Backend de Sincronização local: $erro');
      return -1;
    }),
  );

  _backendLifecycleListener = AppLifecycleListener(
    onExitRequested: () async {
      backendProcessManager.encerrar();
      return AppExitResponse.exit;
    },
  );
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
