import 'package:flutter/material.dart';

import '../pages/connexion.dart';
import '../pages/inscription.dart';

// ============================================================
// MENU COMMUN aux pages Connexion / Inscription
// (icône hamburger de la maquette, à droite de la barre du haut)
// ============================================================
class MenuAuth extends StatelessWidget {
  const MenuAuth({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.login),
            title: const Text('Connexion'),
            onTap: () => Navigator.pushReplacement(context,
                MaterialPageRoute(builder: (_) => const ConnexionPage())),
          ),
          ListTile(
            leading: const Icon(Icons.person_add),
            title: const Text('Inscription'),
            onTap: () => Navigator.pushReplacement(context,
                MaterialPageRoute(builder: (_) => const InscriptionPage())),
          ),
        ],
      ),
    );
  }
}
