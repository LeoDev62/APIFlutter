import 'package:flutter/material.dart';

import 'pages/home.dart';

// ============================================================
// POINT D'ENTRÉE : lance l'application
// (les autres fichiers sont rangés dans api.dart, message.dart,
//  pages/ et widgets/)
// ============================================================
void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // MaterialApp = la "base" de toute app Flutter (thème, navigation...)
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      // L'app démarre sur les messages, ouverts à tous (même sans compte)
      home: HomePage(),
    );
  }
}
