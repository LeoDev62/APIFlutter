import 'dart:convert' as convert; // pour transformer Map <-> texte JSON
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http; // pour envoyer des requêtes à l'API

// ============================================================
// 0. PARTIE API : toutes les communications avec le serveur
// ============================================================

// Adresse de base : changer ici suffit pour changer de serveur
const String baseUrl = 'http://4562.s3.nuage-peda.fr/forum/api';

// Les "IRI" sont les adresses d'objets utilisées par API Platform
// pour faire un lien entre deux objets (ex. : l'auteur d'un message).
const String iriUsers = '/forum/api/users';
const String iriMessages = '/forum/api/messages';

// Noms des champs JSON d'un message.
// ⚠️ Hypothèse à vérifier : si ton API les nomme autrement, change-les ICI
// et nulle part ailleurs.
const String champContenu = 'contenu'; // le texte du message
const String champAuteur = 'user'; // l'auteur (lien vers un utilisateur)
const String champParent = 'parent'; // le message auquel on répond (ou null)

// Le "jeton" (token) reçu à la connexion. Il prouve qui on est au serveur.
// Vide = personne n'est connecté.
String token = '';

// Informations du compte connecté (affichées dans l'onglet Profil)
// Clés possibles : id, nom, prenom, email, roles
Map<String, dynamic> profil = {};

// En-têtes envoyés avec chaque requête.
// Si on est connecté, on ajoute le token ("Bearer" = porteur du jeton).
Map<String, String> entetes(
    {String contentType = 'application/json; charset=UTF-8'}) {
  return {
    'Content-Type': contentType,
    'Accept': 'application/ld+json', // format de réponse d'API Platform
    if (token.isNotEmpty) 'Authorization': 'Bearer $token',
  };
}

// Extrait un numéro (id) depuis une adresse comme "/forum/api/users/31".
// Accepte aussi un nombre déjà prêt, ou un objet JSON contenant "id".
int? idDepuisIri(dynamic valeur) {
  if (valeur == null) return null;
  if (valeur is int) return valeur;
  if (valeur is Map) return idDepuisIri(valeur['id'] ?? valeur['@id']);
  return int.tryParse(valeur.toString().split('/').last);
}

// Un token JWT a 3 parties séparées par des points : la 2e contient les
// infos du compte (e-mail, rôles...) encodées en base64. On la décode ici.
Map<String, dynamic> lireToken(String jwt) {
  try {
    final milieu = jwt.split('.')[1];
    final texte = convert.utf8
        .decode(convert.base64Url.decode(convert.base64Url.normalize(milieu)));
    return convert.jsonDecode(texte) as Map<String, dynamic>;
  } catch (_) {
    return {}; // token illisible : on renvoie "rien"
  }
}

// --- CONNEXION : envoie email + mot de passe, reçoit un token ---
// Renvoie true si ça a marché, false sinon.
Future<bool> seConnecter(String email, String mdp) async {
  try {
    final reponse = await http.post(
      Uri.parse('$baseUrl/authentication_token'),
      headers: entetes(),
      body: convert.jsonEncode({'email': email, 'password': mdp}),
    );
    if (reponse.statusCode == 200) {
      final data = convert.jsonDecode(reponse.body);
      token = data['token'].toString(); // on garde le token pour la suite
      await chargerProfil(email);
      return true;
    }
  } catch (_) {
    // pas de réseau, serveur éteint... on renvoie simplement false
  }
  return false;
}

// --- PROFIL : retrouve les infos du compte qui vient de se connecter ---
// 1) on lit ce que contient le token ; 2) si on connaît l'id du compte,
// on demande le détail à l'API (nom, prénom...).
Future<void> chargerProfil(String emailSaisi) async {
  final infos = lireToken(token);
  profil = {
    'id': idDepuisIri(infos['id']),
    'nom': infos['nom'],
    'prenom': infos['prenom'],
    'email': infos['email'] ?? infos['username'] ?? emailSaisi,
    'roles': infos['roles'] ?? [],
  };

  if (profil['id'] != null) {
    try {
      final reponse = await http.get(
          Uri.parse('$baseUrl/users/${profil['id']}'),
          headers: entetes());
      if (reponse.statusCode == 200) {
        final u = convert.jsonDecode(reponse.body);
        profil['nom'] = u['nom'] ?? profil['nom'];
        profil['prenom'] = u['prenom'] ?? profil['prenom'];
        profil['email'] = u['email'] ?? profil['email'];
      }
    } catch (_) {}
  }
}

// --- INSCRIPTION : crée un utilisateur (POST sur /users) ---
// L'API répond 201 (= "créé") quand ça marche.
Future<bool> creerCompte(
    String nom, String prenom, String email, String mdp) async {
  try {
    final reponse = await http.post(
      Uri.parse('$baseUrl/users'),
      headers: entetes(),
      body: convert.jsonEncode({
        'nom': nom,
        'prenom': prenom,
        'email': email,
        'password': mdp,
      }),
    );
    return reponse.statusCode == 201;
  } catch (_) {
    return false;
  }
}

// --- LISTE DES UTILISATEURS (GET sur /users) ---
// L'API renvoie un objet JSON-LD dont la liste est dans "member"
// (dans les anciennes versions d'API Platform : "hydra:member").
Future<List<Map<String, dynamic>>> recupUtilisateurs() async {
  try {
    final reponse =
        await http.get(Uri.parse('$baseUrl/users'), headers: entetes());
    if (reponse.statusCode == 200) {
      final data = convert.jsonDecode(reponse.body);
      final liste = data['member'] ?? data['hydra:member'] ?? [];
      return [
        for (final u in liste)
          {
            'id': u['id'],
            'nom': u['nom'],
            'prenom': u['prenom'],
            'suspendu': false, // l'API ne gère pas "suspendu" : local pour l'instant
          }
      ];
    }
  } catch (_) {}
  return []; // en cas de problème : liste vide
}

// --- SUPPRESSION d'un utilisateur (DELETE sur /users/id) ---
// L'API répond 204 (= "ok, rien à renvoyer") quand ça marche.
Future<bool> supprimerUtilisateur(int id) async {
  try {
    final reponse =
        await http.delete(Uri.parse('$baseUrl/users/$id'), headers: entetes());
    return reponse.statusCode == 204;
  } catch (_) {
    return false;
  }
}

// ------------------------------------------------------------
// MESSAGES (API /messages)
// ------------------------------------------------------------

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

// Dictionnaire "numéro d'utilisateur -> Prénom Nom", pour afficher les auteurs
Future<Map<int, String>> recupNomsUtilisateurs() async {
  final noms = <int, String>{};
  for (final u in await recupUtilisateurs()) {
    noms[u['id']] = '${u['prenom']} ${u['nom']}';
  }
  return noms;
}

// --- LISTE DES MESSAGES (GET sur /messages) ---
// L'API renvoie une liste "à plat" : chaque réponse indique son parent.
// On la transforme en arbre : message -> réponses -> réponses...
Future<List<Message>> recupMessages() async {
  try {
    final noms = await recupNomsUtilisateurs();
    final reponse =
        await http.get(Uri.parse('$baseUrl/messages'), headers: entetes());
    if (reponse.statusCode == 200) {
      final data = convert.jsonDecode(reponse.body);
      final liste = data['member'] ?? data['hydra:member'] ?? [];

      // 1er passage : on crée tous les messages, rangés par id
      final parId = <int, Message>{};
      for (final m in liste) {
        // L'auteur peut arriver sous forme d'adresse ou d'objet complet
        var auteur = '';
        final brut = m[champAuteur];
        if (brut is Map) {
          auteur = '${brut['prenom'] ?? ''} ${brut['nom'] ?? ''}'.trim();
        } else {
          auteur = noms[idDepuisIri(brut)] ?? '';
        }
        parId[m['id']] = Message(
          id: m['id'],
          texte: (m[champContenu] ?? '').toString(),
          auteur: auteur,
        );
      }

      // 2e passage : on accroche chaque message à son parent
      final racines = <Message>[];
      for (final m in liste) {
        final message = parId[m['id']]!;
        final parent = parId[idDepuisIri(m[champParent])];
        if (parent != null) {
          parent.reponses.add(message); // c'est une réponse
        } else {
          racines.add(message); // message de premier niveau
        }
      }
      return racines;
    }
  } catch (_) {}
  return [];
}

// --- CRÉER un message (POST sur /messages) ---
// parentId : numéro du message auquel on répond (rien = nouveau message).
// L'API répond 201 (= "créé") quand ça marche.
Future<bool> creerMessage(String texte, {int? parentId}) async {
  try {
    final reponse = await http.post(
      Uri.parse('$baseUrl/messages'),
      headers: entetes(),
      body: convert.jsonEncode({
        champContenu: texte,
        // l'auteur = le compte connecté (si on connaît son id)
        if (profil['id'] != null) champAuteur: '$iriUsers/${profil['id']}',
        if (parentId != null) champParent: '$iriMessages/$parentId',
      }),
    );
    return reponse.statusCode == 201;
  } catch (_) {
    return false;
  }
}

// --- MODIFIER un message (PATCH sur /messages/id) ---
// PATCH = on n'envoie que ce qui change. API Platform exige ce type
// de contenu précis pour PATCH : "application/merge-patch+json".
Future<bool> modifierMessage(int id, String texte) async {
  try {
    final reponse = await http.patch(
      Uri.parse('$baseUrl/messages/$id'),
      headers: entetes(contentType: 'application/merge-patch+json'),
      body: convert.jsonEncode({champContenu: texte}),
    );
    return reponse.statusCode == 200;
  } catch (_) {
    return false;
  }
}

// --- SUPPRIMER un message (DELETE sur /messages/id) ---
// L'API répond 204 quand ça marche.
Future<bool> supprimerMessage(int id) async {
  try {
    final reponse = await http.delete(Uri.parse('$baseUrl/messages/$id'),
        headers: entetes());
    return reponse.statusCode == 204;
  } catch (_) {
    return false;
  }
}

// ============================================================
// 1. POINT D'ENTRÉE : lance l'application
// ============================================================
void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // MaterialApp = la "base" de toute app Flutter (thème, navigation...)
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: ConnexionPage(), // l'app démarre sur l'écran de connexion
    );
  }
}

// ============================================================
// 1 bis. BOUTONS DE LA BARRE DU HAUT (AppBar)
// ============================================================

// Bouton "déconnecter" : efface le token et le profil, puis revient à
// l'écran de connexion. pushAndRemoveUntil(..., (route) => false) vide
// l'historique : le bouton retour ne permet pas de revenir dans l'app.
class BoutonDeconnexion extends StatelessWidget {
  const BoutonDeconnexion({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.logout),
      tooltip: 'Déconnecter',
      onPressed: () {
        token = '';
        profil = {};
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const ConnexionPage()),
          (route) => false,
        );
      },
    );
  }
}

// Bouton hamburger qui ouvre le menu de droite (endDrawer).
// Quand on met ses propres boutons dans "actions", il faut l'ajouter soi-même.
class BoutonMenu extends StatelessWidget {
  const BoutonMenu({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.menu),
      tooltip: 'Menu',
      onPressed: () => Scaffold.of(context).openEndDrawer(),
    );
  }
}

// ============================================================
// 1 ter. MENU COMMUN aux pages Connexion / Inscription
//        (icône hamburger de la maquette, à droite de la barre du haut)
// ============================================================
class MenuAuth extends StatelessWidget {
  const MenuAuth({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.login),
            title: const Text('Connexion'),
            onTap: () => Navigator.pushReplacement(context,
                MaterialPageRoute(builder: (_) => const ConnexionPage())),
          ),
          ListTile(
            leading: const Icon(Icons.person_add),
            title: const Text('Inscription'),
            onTap: () => Navigator.pushReplacement(context,
                MaterialPageRoute(builder: (_) => const InscriptionPage())),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// 1 quater. CHAMP DE SAISIE réutilisable
//        - label : le texte indicatif (ex. "email")
//        - motDePasse : true = les caractères sont masqués (••••)
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

// ============================================================
// 1 quinquies. ÉCRAN CONNEXION (titre : "Connexion")
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

// ============================================================
// 1 sexies. ÉCRAN INSCRIPTION (titre : "Inscription")
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

    // Envoi des infos au serveur pour créer le compte
    final ok = await creerCompte(
        nom.text, prenom.text, email.text, motDePasse.text);
    if (!mounted) return;

    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Compte créé, connecte-toi !')));
      // Compte créé : on renvoie vers la connexion (pas encore de token)
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (_) => const ConnexionPage()));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Inscription impossible (email déjà utilisé ?)')));
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

// ============================================================
// 2. FONCTION UTILE : ouvre une petite fenêtre pour saisir du texte
//    (sert pour "modifier", "répondre" et le bouton "+")
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

// ============================================================
// 3. ÉCRAN PRINCIPAL (titre : "Forum" ou "Profil" selon l'onglet)
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

// ============================================================
// 4. ONGLET PROFIL : affiche les infos du compte connecté
//    (elles viennent de la variable globale "profil", remplie à la connexion)
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

// ============================================================
// 5. WIDGET "UN MESSAGE" : affiche l'auteur, le texte, les 3 boutons
//    et (récursivement) toutes ses réponses décalées vers la droite.
//    Il ne parle pas au serveur lui-même : il appelle les fonctions
//    onReply / onEdit / onDelete fournies par HomePage.
// ============================================================
class MessageTile extends StatelessWidget {
  final Message message;
  final Future<void> Function(Message parent, String texte) onReply;
  final Future<void> Function(Message message, String texte) onEdit;
  final Future<void> Function(Message message) onDelete;

  const MessageTile({
    super.key,
    required this.message,
    required this.onReply,
    required this.onEdit,
    required this.onDelete,
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

        // Les boutons sous le message (collés grâce à styleBouton)
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
        ),

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
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// ============================================================
// 6. ÉCRAN ADMINISTRATION (titre : "Administration")
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