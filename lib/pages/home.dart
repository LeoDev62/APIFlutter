import 'package:flutter/material.dart';

import '../api.dart';
import '../message.dart';
import '../widgets/boutons_appbar.dart';
import '../widgets/demander_texte.dart';
import '../widgets/message_tile.dart';
import '../widgets/profil_vue.dart';
import 'admin.dart';
import 'connexion.dart';
import 'inscription.dart';

// ============================================================
// ÉCRAN PRINCIPAL (titre : "Forum" ou "Profil" selon l'onglet)
//
// Deux modes :
//  - VISITEUR (pas connecté) : on lit les messages, c'est tout.
//    Pas de bouton +, pas de boutons sous les messages, pas de profil.
//    Le menu de droite propose "connexion" et "inscription".
//  - CONNECTÉ : on peut écrire, répondre, modifier, supprimer,
//    voir son profil, et accéder à l'administration.
// ============================================================
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // Onglet sélectionné dans la barre du bas : 0 = Post, 1 = Profil
  // (un visiteur reste toujours sur 0 : il n'a pas de barre du bas)
  int onglet = 0;

  // Messages chargés depuis l'API
  List<Message> messages = [];
  bool chargement = true; // true tant que le serveur n'a pas répondu

  // initState = s'exécute une seule fois à l'ouverture de l'écran
  @override
  void initState() {
    super.initState();
    charger();
  }

  // (Re)télécharge les messages depuis le serveur et redessine l'écran
  Future<void> charger() async {
    final liste = await recupMessages();
    if (!mounted) return;
    setState(() {
      messages = liste;
      chargement = false;
    });
  }

  // Après chaque action : si le serveur a accepté, on recharge la liste,
  // sinon on affiche un message d'erreur.
  Future<void> apresAction(bool ok, String erreur) async {
    if (!mounted) return;
    if (ok) {
      await charger();
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(erreur)));
    }
  }

  // --- Les 3 actions sur un message (envoyées aux MessageTile) ---
  Future<void> repondre(Message parent, String texte) async {
    final ok = await creerMessage(texte, parentId: parent.id);
    await apresAction(ok, 'Réponse impossible');
  }

  Future<void> modifier(Message m, String texte) async {
    final ok = m.id != null && await modifierMessage(m.id!, texte);
    await apresAction(ok, "Modification impossible (ce message n'est pas à toi ?)");
  }

  Future<void> supprimer(Message m) async {
    final ok = m.id != null && await supprimerMessage(m.id!);
    await apresAction(ok, "Suppression impossible (ce message n'est pas à toi ?)");
  }

  // Contenu du menu de droite (endDrawer), selon le mode
  Widget menuDroite(bool connecte) {
    return Drawer(
      child: ListView(
        children: [
          if (connecte)
            // Connecté : accès à l'administration
            ListTile(
              leading: const Icon(Icons.admin_panel_settings),
              title: const Text('Administration'),
              onTap: () {
                Navigator.pop(context); // ferme le menu
                // Navigator.push = aller vers un autre écran
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const AdminPage()));
              },
            )
          else
            // Visiteur : deux boutons pour entrer dans l'application
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch, // boutons pleine largeur
                children: [
                  ElevatedButton(
                    child: const Text('connexion'),
                    onPressed: () {
                      Navigator.pop(context); // ferme le menu
                      Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const ConnexionPage()));
                    },
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    child: const Text('inscription'),
                    onPressed: () {
                      Navigator.pop(context); // ferme le menu
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const InscriptionPage()));
                    },
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Connecté ou simple visiteur ?
    final connecte = estConnecte;
    // Un visiteur ne voit que les messages, quel que soit l'onglet
    final voirMessages = !connecte || onglet == 0;

    return Scaffold(
      // Scaffold = squelette d'un écran (barre du haut, contenu, barre du bas...)

      // --- Barre du haut : titre + (déconnecter si connecté) + menu ---
      appBar: AppBar(
        title: Text(voirMessages ? 'Forum' : 'Profil'),
        actions: [
          if (connecte) const BoutonDeconnexion(),
          const BoutonMenu(),
        ],
      ),

      // --- Menu de droite, différent selon le mode ---
      endDrawer: menuDroite(connecte),

      // --- Contenu : liste des messages OU profil selon l'onglet ---
      body: voirMessages
          ? (chargement
              ? const Center(child: CircularProgressIndicator())
              : messages.isEmpty
                  ? const Center(child: Text('Aucun message pour le moment'))
                  : ListView(
                      // Pas de marge gauche/droite : les messages touchent les bords
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      children: [
                        for (final m in messages)
                          MessageTile(
                            message: m,
                            interactif: connecte, // visiteur = lecture seule
                            onReply: repondre,
                            onEdit: modifier,
                            onDelete: supprimer,
                          ),
                      ],
                    ))
          : const ProfilVue(),

      // --- Bouton rond "+" : écrire un message (connecté, onglet Post) ---
      floatingActionButton: connecte && onglet == 0
          ? FloatingActionButton(
              child: const Icon(Icons.add),
              onPressed: () async {
                final texte = await demanderTexte(context, 'Nouveau message');
                if (texte != null && texte.isNotEmpty) {
                  final ok = await creerMessage(texte);
                  await apresAction(ok, 'Envoi impossible');
                }
              },
            )
          : null,

      // --- Barre du bas : "Post" et "Profil" (seulement si connecté) ---
      bottomNavigationBar: connecte
          ? BottomNavigationBar(
              currentIndex: onglet,
              onTap: (i) => setState(() => onglet = i),
              items: const [
                BottomNavigationBarItem(icon: Icon(Icons.article), label: 'Post'),
                BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profil'),
              ],
            )
          : null,
    );
  }
}
