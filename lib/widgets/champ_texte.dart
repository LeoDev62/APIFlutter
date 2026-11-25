import 'package:flutter/material.dart';

// ============================================================
// CHAMP DE SAISIE réutilisable
//   - label : le texte indicatif (ex. "email")
//   - motDePasse : true = les caractères sont masqués (••••)
// ============================================================
class ChampTexte extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final bool motDePasse;
  final TextInputType clavier;

  const ChampTexte({
    super.key,
    required this.label,
    required this.controller,
    this.motDePasse = false,
    this.clavier = TextInputType.text,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16), // espace entre les champs
      child: TextField(
        controller: controller, // permet de récupérer ce que l'utilisateur écrit
        obscureText: motDePasse,
        keyboardType: clavier,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}
