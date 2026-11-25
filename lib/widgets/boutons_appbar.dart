import 'package:flutter/material.dart';

import '../api.dart';
import '../pages/connexion.dart';

// ============================================================
// BOUTONS DE LA BARRE DU HAUT (AppBar)
// ============================================================

// Bouton "déconnecter" : efface le token et le profil, puis revient à
// l'écran de connexion. pushAndRemoveUntil(..., (route) => false) vide
// l'historique : le bouton retour ne permet pas de revenir dans l'app.
class BoutonDeconnexion extends StatelessWidget {
  const BoutonDeconnexion({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.logout),
      tooltip: 'Déconnecter',
      onPressed: () {
        token = '';
        profil = {};
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const ConnexionPage()),
          (route) => false,
        );
      },
    );
  }
}

// Bouton hamburger qui ouvre le menu de droite (endDrawer).
// Quand on met ses propres boutons dans "actions", il faut l'ajouter soi-même.
class BoutonMenu extends StatelessWidget {
  const BoutonMenu({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.menu),
      tooltip: 'Menu',
      onPressed: () => Scaffold.of(context).openEndDrawer(),
    );
  }
}
