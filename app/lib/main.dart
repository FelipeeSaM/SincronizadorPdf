import 'dart:async';
import 'dart:io';
import 'dart:ui' show AppExitResponse;

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import 'home_screen.dart';
import 'sync/backend_dll_resolver.dart';
import 'sync/backend_process_manager.dart';
import 'sync/device_id_store.dart';
import 'theme_mode_store.dart';

// Mantidos em variáveis top-level (não locais a `main()`) para que o
// `AppLifecycleListener` não seja coletado pelo GC antes do app fechar —
// ver #24. Nunca lidas de volta: existir já é o efeito que importa.
// ignore: unused_element
BackendProcessManager? _backendProcessManager;
// ignore: unused_element
AppLifecycleListener? _backendLifecycleListener;

void main() {
  final enderecoBackendLocal = Platform.isLinux
      ? _iniciarBackendLocal()
      : null;

  runApp(SincronizadorPdfApp(enderecoBackendLocal: enderecoBackendLocal));
}

/// Inicia o Backend de Sincronização como processo filho do app desktop
/// (Linux) e garante que ele morre junto quando o app fecha — trade-off
/// aceito em #24: sem esse Backend local, o app continua funcionando
/// normalmente, só sem o processo próprio (ex: layout de dev incompleto).
///
/// Resolve com `http://localhost:<porta>` assim que o Backend reporta a
/// porta efetiva (ver #24), para o resto do app usar automaticamente, sem
/// pedir o endereço manualmente (ver #26) — ou `null` se o Backend local não
/// puder ser iniciado, caso em que quem chama cai de volta no fluxo manual.
Future<String?> _iniciarBackendLocal() async {
  // Tudo dentro de um único try/catch, não só `backendProcessManager.iniciar()`
  // — o Future retornado nunca pode rejeitar: ele é aguardado em paralelo por
  // HomeScreen e PairingScreen (ver #26), e uma rejeição ali, sem tratamento,
  // travaria a tela de Pareamento e pularia o fallback para o endereço salvo
  // manualmente em vez de simplesmente cair para `null`.
  try {
    final caminhoDll = resolverCaminhoBackendDll(
      environment: Platform.environment,
      diretorioAtual: Directory.current,
    );
    if (caminhoDll == null) return null;

    // Repassado ao Backend para o TXT record do anúncio mDNS (ver #25) — é
    // isso que permite ao celular desambiguar entre múltiplos backends
    // SincronizadorPdf na mesma rede.
    final dispositivoId = await const DeviceIdStore().obterOuCriar();

    final backendProcessManager = BackendProcessManager(
      executavel: 'dotnet',
      argumentos: [caminhoDll],
      environment: {
        'SINCRONIZADOR_PDF_LAN_MODE': '1',
        'SINCRONIZADOR_PDF_DEVICE_ID': dispositivoId,
      },
      // Sem isto, o Backend herdaria o diretório de trabalho do app desktop
      // e espalharia os bancos SQLite (ContentRootPath) num lugar
      // imprevisível — ver #24.
      workingDirectory: p.dirname(caminhoDll),
    );
    _backendProcessManager = backendProcessManager;

    _backendLifecycleListener = AppLifecycleListener(
      onExitRequested: () async {
        backendProcessManager.encerrar();
        return AppExitResponse.exit;
      },
    );

    final porta = await backendProcessManager.iniciar();
    return 'http://localhost:$porta';
  } catch (erro) {
    // O app continua funcionando sem o Backend local (ex: `dotnet` fora
    // do PATH, ou o .dll de dev ainda não foi buildado) — mesma
    // tolerância a Backend indisponível que o resto do app já tem, caindo
    // de volta no fluxo manual de endereço do Backend (ver #26).
    debugPrint('Falha ao iniciar o Backend de Sincronização local: $erro');
    return null;
  }
}

class SincronizadorPdfApp extends StatefulWidget {
  const SincronizadorPdfApp({super.key, this.enderecoBackendLocal});

  /// `http://localhost:<porta>` do Backend local (ver #24), ou `null` em
  /// plataformas sem Backend local (ex: celular) ou se ele não iniciou —
  /// nesses casos o fluxo manual de endereço do Backend continua disponível
  /// (ver #26).
  final Future<String?>? enderecoBackendLocal;

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
            enderecoBackendLocal: widget.enderecoBackendLocal,
          ),
        );
      },
    );
  }
}
