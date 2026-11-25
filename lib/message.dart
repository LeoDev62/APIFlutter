// ============================================================
// MODÈLE DE DONNÉES : un message du forum
// ============================================================

// Un message : son numéro (id), son texte, son auteur et ses réponses.
// Les réponses sont elles-mêmes des Message.
class Message {
  final int? id;
  String texte;
  String auteur; // "Prénom Nom" (vide si inconnu)
  List<Message> reponses;

  Message({
    this.id,
    required this.texte,
    this.auteur = '',
    List<Message>? reponses,
  }) : reponses = reponses ?? [];
}
