import 'dart:convert' as convert; // pour transformer Map <-> texte JSON

import 'package:http/http.dart' as http; // pour envoyer des requêtes à l'API

import 'message.dart';

// ============================================================
// PARTIE API : toutes les communications avec le serveur
// (aucun widget ici : seulement des données et des requêtes)
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

// true si quelqu'un est connecté (un token est présent).
// Sinon, on est "visiteur" : on peut lire les messages sans agir dessus.
bool get estConnecte => token.isNotEmpty;

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

// ------------------------------------------------------------
// COMPTES : connexion, profil, inscription
// ------------------------------------------------------------

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

// ------------------------------------------------------------
// UTILISATEURS (administration)
// ------------------------------------------------------------

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
