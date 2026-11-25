import 'package:flutter/material.dart';

import '../api.dart';

// ============================================================
// ONGLET PROFIL : affiche les infos du compte connecté
// (elles viennent de la variable globale "profil", remplie à la connexion)
// ============================================================
class ProfilVue extends StatelessWidget {
  const ProfilVue({super.key});

  // Une ligne "icône + libellé + valeur" ("Non renseigné" si vide)
  Widget ligne(IconData icone, String libelle, String? valeur) {
    return ListTile(
      leading: Icon(icone),
      title: Text(libelle),
      subtitle: Text(
          valeur == null || valeur.isEmpty ? 'Non renseigné' : valeur),
    );
  }

  @override
  Widget build(BuildContext context) {
    final roles = (profil['roles'] as List?)?.join(', ');
    return ListView(
      children: [
        const SizedBox(height: 24),
        const Center(
          child: CircleAvatar(radius: 40, child: Icon(Icons.person, size: 40)),
        ),
        const SizedBox(height: 16),
        ligne(Icons.badge, 'Nom', profil['nom']?.toString()),
        ligne(Icons.badge_outlined, 'Prénom', profil['prenom']?.toString()),
        ligne(Icons.email, 'Email', profil['email']?.toString()),
      ],
    );
  }
}
