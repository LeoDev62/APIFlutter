import 'package:flutter/material.dart';

import '../api.dart';
import '../message.dart';
import '../widgets/boutons_appbar.dart';
import '../widgets/demander_texte.dart';
import '../widgets/message_tile.dart';
import '../widgets/profil_vue.dart';
import 'admin.dart';

// ============================================================
// ÉCRAN PRINCIPAL (titre : "Forum" ou "Profil" selon l'onglet)
// ============================================================
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // Onglet sélectionné dans la barre du bas : 0 = Post, 1 = Profil
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Scaffold = squelette d'un écran (barre du haut, contenu, barre du bas...)

      // --- Barre du haut : titre + bouton déconnecter + bouton menu ---
      appBar: AppBar(
        title: Text(onglet == 0 ? 'Forum' : 'Profil'),
        actions: const [BoutonDeconnexion(), BoutonMenu()],
      ),

      // --- Menu qui s'ouvre avec l'icône hamburger (à droite) ---
      endDrawer: Drawer(
        child: ListView(
          children: [
            ListTile(
              leading: const Icon(Icons.admin_panel_settings),
              title: const Text('Administration'),
              onTap: () {
                Navigator.pop(context); // ferme le menu
                // Navigator.push = aller vers un autre écran
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const AdminPage()));
              },
            ),
          ],
        ),
      ),

      // --- Contenu : liste des messages OU profil selon l'onglet ---
      body: onglet == 0
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
                            onReply: repondre,
                            onEdit: modifier,
                            onDelete: supprimer,
                          ),
                      ],
                    ))
          : const ProfilVue(),

      // --- Bouton rond "+" : ajoute un nouveau message (seulement sur Post) ---
      floatingActionButton: onglet == 0
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

      // --- Barre du bas : "Post" et "Profil" ---
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: onglet,
        onTap: (i) => setState(() => onglet = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.article), label: 'Post'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profil'),
        ],
      ),
    );
  }
}
