import 'package:flutter/material.dart';

import '../api.dart';
import '../widgets/champ_texte.dart';
import '../widgets/menu_auth.dart';
import 'home.dart';

// ============================================================
// ÉCRAN CONNEXION (titre : "Connexion")
// ============================================================
class ConnexionPage extends StatefulWidget {
  const ConnexionPage({super.key});

  @override
  State<ConnexionPage> createState() => _ConnexionPageState();
}

class _ConnexionPageState extends State<ConnexionPage> {
  // Un controller par champ : il "garde en mémoire" le texte saisi
  final email = TextEditingController();
  final motDePasse = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Connexion')),
      endDrawer: const MenuAuth(),
      // Center + SingleChildScrollView = formulaire centré, qui défile
      // si le clavier prend de la place
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min, // la colonne ne prend que la place utile
            children: [
              ChampTexte(
                label: 'email',
                controller: email,
                clavier: TextInputType.emailAddress,
              ),
              ChampTexte(
                  label: 'mot de passe',
                  controller: motDePasse,
                  motDePasse: true),
              const SizedBox(height: 8),
              ElevatedButton(
                child: const Text('connexion'),
                // async : on attend la réponse du serveur avant de continuer
                onPressed: () async {
                  final ok = await seConnecter(email.text, motDePasse.text);
                  if (!mounted) return; // l'écran a été fermé entre-temps
                  if (ok) {
                    Navigator.pushReplacement(context,
                        MaterialPageRoute(builder: (_) => const HomePage()));
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('Email ou mot de passe incorrect')));
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
