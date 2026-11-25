import 'package:flutter/material.dart';

import '../api.dart';
import '../widgets/boutons_appbar.dart';

// ============================================================
// ÉCRAN ADMINISTRATION (titre : "Administration")
// ============================================================
class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  // Liste des utilisateurs, remplie depuis l'API
  List<Map<String, dynamic>> utilisateurs = [];
  bool chargement = true; // true tant que le serveur n'a pas répondu

  // initState = s'exécute une seule fois à l'ouverture de l'écran
  @override
  void initState() {
    super.initState();
    charger();
  }

  Future<void> charger() async {
    final liste = await recupUtilisateurs();
    if (!mounted) return;
    setState(() {
      utilisateurs = liste;
      chargement = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Le bouton retour (←) est ajouté automatiquement par AppBar
      appBar: AppBar(
        title: const Text('Administration'),
        actions: const [BoutonDeconnexion()],
      ),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text('Liste Utilisateur',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          ),
          // Expanded + ListView = liste qui prend tout l'espace restant
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              children: [
                // Petit rond qui tourne pendant le chargement
                if (chargement)
                  const Center(child: CircularProgressIndicator()),
                for (final u in utilisateurs)
                  Column(
                    children: [
                      Card(
                        child: ListTile(
                          title: Text('${u['prenom']} ${u['nom']}'),
                          // Petit texte si l'utilisateur est suspendu
                          subtitle: u['suspendu'] ? const Text('Suspendu') : null,
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            // Inverse l'état suspendu / non suspendu
                            onPressed: () => setState(
                                () => u['suspendu'] = !u['suspendu']),
                            child: Text(
                                u['suspendu'] ? 'réactiver' : 'suspendre'),
                          ),
                          TextButton(
                            onPressed: () async {
                              // On supprime d'abord côté serveur...
                              final ok = await supprimerUtilisateur(u['id']);
                              if (!mounted) return;
                              if (ok) {
                                // ...puis dans la liste affichée
                                setState(() => utilisateurs.remove(u));
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text(
                                            'Suppression impossible (droits admin ?)')));
                              }
                            },
                            child: const Text('supprimer'),
                          ),
                        ],
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
