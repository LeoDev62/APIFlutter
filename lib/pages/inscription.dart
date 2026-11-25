import 'package:flutter/material.dart';

import '../api.dart';
import '../widgets/champ_texte.dart';
import '../widgets/menu_auth.dart';
import 'connexion.dart';

// ============================================================
// ÉCRAN INSCRIPTION (titre : "Inscription")
// ============================================================
class InscriptionPage extends StatefulWidget {
  const InscriptionPage({super.key});

  @override
  State<InscriptionPage> createState() => _InscriptionPageState();
}

class _InscriptionPageState extends State<InscriptionPage> {
  final nom = TextEditingController();
  final prenom = TextEditingController();
  final email = TextEditingController();
  final motDePasse = TextEditingController();
  final confirmation = TextEditingController();

  // Vérifie le formulaire quand on clique sur "inscription"
  Future<void> sInscrire() async {
    String? erreur;
    if (nom.text.isEmpty || prenom.text.isEmpty || email.text.isEmpty) {
      erreur = 'Merci de remplir tous les champs';
    } else if (motDePasse.text != confirmation.text) {
      erreur = 'Les mots de passe ne sont pas identiques';
    }

    if (erreur != null) {
      // SnackBar = petit message temporaire en bas de l'écran
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(erreur)));
      return; // on s'arrête là
    }

    // Envoi des infos au serveur pour créer le compte.
    // creerCompte renvoie null si ça marche, sinon le texte de l'erreur.
    final erreurServeur = await creerCompte(
        nom.text, prenom.text, email.text, motDePasse.text);
    if (!mounted) return;

    if (erreurServeur == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Compte créé, connecte-toi !')));
      // Compte créé : on renvoie vers la connexion (pas encore de token)
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (_) => const ConnexionPage()));
    } else {
      // On affiche la vraie raison donnée par le serveur, plus longtemps
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Inscription impossible. $erreurServeur'),
        duration: const Duration(seconds: 10),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Inscription')),
      endDrawer: const MenuAuth(),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ChampTexte(label: 'nom', controller: nom),
              ChampTexte(label: 'prénom', controller: prenom),
              ChampTexte(
                label: 'email',
                controller: email,
                clavier: TextInputType.emailAddress,
              ),
              ChampTexte(
                  label: 'mot de passe',
                  controller: motDePasse,
                  motDePasse: true),
              ChampTexte(
                  label: 'confirmation mot de passe',
                  controller: confirmation,
                  motDePasse: true),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: sInscrire,
                child: const Text('inscription'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
