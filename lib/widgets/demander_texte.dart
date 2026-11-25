import 'package:flutter/material.dart';

// ============================================================
// FONCTION UTILE : ouvre une petite fenêtre pour saisir du texte
// (sert pour "modifier", "répondre" et le bouton "+")
// Renvoie le texte saisi, ou null si on annule.
// ============================================================
Future<String?> demanderTexte(BuildContext context, String titre,
    [String initial = '']) {
  final controller = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (_) => AlertDialog(
      title: Text(titre),
      content: TextField(controller: controller, autofocus: true),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler')),
        TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('OK')),
      ],
    ),
  );
}
