import 'package:flutter/material.dart';

import '../message.dart';
import 'demander_texte.dart';

// ============================================================
// WIDGET "UN MESSAGE" : affiche l'auteur, le texte, les 3 boutons
// et (récursivement) toutes ses réponses décalées vers la droite.
// Il ne parle pas au serveur lui-même : il appelle les fonctions
// onReply / onEdit / onDelete fournies par HomePage.
// interactif = false (visiteur non connecté) : on ne voit que le message,
// sans les boutons répondre / modifier / supprimer.
// ============================================================
class MessageTile extends StatelessWidget {
  final Message message;
  final bool interactif;
  final Future<void> Function(Message parent, String texte) onReply;
  final Future<void> Function(Message message, String texte) onEdit;
  final Future<void> Function(Message message) onDelete;

  const MessageTile({
    super.key,
    required this.message,
    required this.onReply,
    required this.onEdit,
    required this.onDelete,
    this.interactif = true,
  });

  @override
  Widget build(BuildContext context) {
    // Style compact : supprime l'espace autour des boutons pour les coller au message
    final styleBouton = TextButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      minimumSize: Size.zero,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // SizedBox(width: infinity) = prend toute la largeur disponible
        SizedBox(
          width: double.infinity,
          child: Card(
            margin: const EdgeInsets.only(bottom: 0), // pas de marge autour
            shape: const RoundedRectangleBorder(), // coins droits, bord à bord
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Nom de l'auteur (affiché seulement s'il est connu)
                  if (message.auteur.isNotEmpty)
                    Text(message.auteur,
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.bold)),
                  Text(message.texte, style: const TextStyle(fontSize: 18)),
                ],
              ),
            ),
          ),
        ),

        // Les boutons sous le message (collés grâce à styleBouton),
        // visibles seulement pour un utilisateur connecté
        if (interactif)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton(
              style: styleBouton,
              child: const Text('répondre'),
              onPressed: () async {
                final texte = await demanderTexte(context, 'Votre réponse');
                if (texte != null && texte.isNotEmpty) {
                  await onReply(message, texte);
                }
              },
            ),
            TextButton(
              style: styleBouton,
              child: const Text('modifier'),
              onPressed: () async {
                final texte =
                    await demanderTexte(context, 'Modifier', message.texte);
                if (texte != null && texte.isNotEmpty) {
                  await onEdit(message, texte);
                }
              },
            ),
            TextButton(
              style: styleBouton,
              onPressed: () => onDelete(message),
              child: const Text('supprimer'),
            ),
          ],
        )
        else
          // Visiteur : un petit espace à la place des boutons
          const SizedBox(height: 6),

        // Les réponses : décalées de 32 px à gauche, mais jusqu'au bord droit
        Padding(
          padding: const EdgeInsets.only(left: 32),
          child: Column(
            children: [
              for (final r in message.reponses)
                MessageTile(
                  message: r, // on réutilise le même widget : c'est la récursivité
                  onReply: onReply,
                  onEdit: onEdit,
                  onDelete: onDelete,
                  interactif: interactif,
                ),
            ],
          ),
        ),
      ],
    );
  }
}
