# SuperFaster

Application mobile de livraison (restaurants, courses, colis) — **frontend uniquement**.
Aucun backend, aucune API, aucun Firebase : toutes les données sont des mocks écrits en dur
dans les dossiers `data/` de chaque module.

## Lancer le projet

```bash
flutter pub get
flutter run            # téléphone / émulateur Android ou iOS
flutter run -d chrome  # aperçu rapide dans le navigateur
```

Une connexion Internet est nécessaire au premier lancement : les polices (Google Fonts)
et les photos (Unsplash) sont chargées depuis le réseau.

> **Windows :** si `flutter run` affiche « Building with plugins requires symlink support »,
> activez le *Mode développeur* (`start ms-settings:developers`).

### Données de démonstration

| Élément | Valeur |
| --- | --- |
| Connexion | champs pré-remplis (n'importe quel e-mail valide + 6 caractères) |
| Code OTP | `1234` |
| Codes promo | `BIENVENUE30` (-30 %), `FAST5` (5 € offerts), `LIVRAISON` (livraison offerte) |
| Commande en cours | `#SF1046` : son suivi avance automatiquement (préparation → en route → livrée) |

## Dépendances

| Package | Rôle |
| --- | --- |
| `go_router` | navigation, barre du bas (StatefulShellRoute), transitions personnalisées |
| `google_fonts` | Poppins (titres) et Inter (texte) |
| `flutter_animate` | cascades d'apparition, micro-interactions |
| `shimmer` | squelettes de chargement |
| `lottie` | animations bienvenue / commande confirmée / panier vide |

Les animations Lottie (`assets/lottie/`) sont générées par `tool/generate_lottie.py` ;
vous pouvez les remplacer par des fichiers LottieFiles portant les mêmes noms.

## Architecture

```
lib/
├── core/
│   ├── constants/   couleurs, tailles, durées, chemins d'assets
│   ├── routes/      routes go_router, transitions, coque des onglets
│   ├── theme/       thème Material 3 clair/sombre, palette, ThemeController
│   ├── utils/       formatage (prix, dates), validateurs de formulaires
│   └── widgets/     composants réutilisables (boutons, champs, shimmer…)
├── features/
│   ├── auth/        splash, onboarding, connexion, inscription, OTP, mot de passe
│   ├── catalog/     accueil, recherche, restaurants, menu, produit, favoris
│   ├── orders/      panier, validation, confirmation, historique
│   ├── delivery/    suivi de commande (carte simulée), envoi de colis
│   ├── profile/     profil, adresses, paiements, langue, notifications
│   └── admin/       tableau de bord (démo)
└── main.dart
```

Chaque module suit la même organisation : `data/` (mocks), `models/`,
`presentation/` (`pages/`, `widgets/`, `controllers/`).

L'état partagé (panier, commandes, favoris, profil, thème) repose sur de simples
`ChangeNotifier` écoutés avec `ListenableBuilder`, sans package externe. Pour brancher
un vrai backend, il suffira de remplacer les classes `*MockData` par des repositories
et, si besoin, ces contrôleurs par Provider, Riverpod ou Bloc.

## Tests

```bash
flutter analyze
flutter test
```

- `cart_controller_test.dart` : calculs du panier et codes promo ;
- `lottie_assets_test.dart` : les 3 animations se chargent ;
- `screens_smoke_test.dart` : les 32 écrans s'affichent sans erreur ni débordement
  (petit et grand téléphone, clair et sombre) ;
- `navigation_flow_test.dart` : parcours complet accueil → restaurant → produit →
  panier → paiement → confirmation → suivi.
