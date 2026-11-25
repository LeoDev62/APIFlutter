import 'package:flutter/material.dart';

import 'pages/connexion.dart';

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
      home: ConnexionPage(), // l'app démarre sur l'écran de connexion
    );
  }
}
