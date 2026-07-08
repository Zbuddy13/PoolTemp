import 'package:flutter/material.dart';

import 'screens/home_screen.dart';

void main() {
  runApp(const PoolTempApp());
}

class PoolTempApp extends StatelessWidget {
  const PoolTempApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF2A78D6);
    return MaterialApp(
      title: 'PoolTemp',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: seed),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme:
            ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.dark),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
