import 'package:flutter/material.dart';

import 'home_screen.dart';

void main() {
  runApp(const SincronizadorPdfApp());
}

class SincronizadorPdfApp extends StatelessWidget {
  const SincronizadorPdfApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sincronizador PDF',
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple)),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
      ),
      themeMode: ThemeMode.system,
      home: const HomeScreen(),
    );
  }
}
