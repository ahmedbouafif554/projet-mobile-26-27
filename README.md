# SuperFaster

Application mobile de livraison (restaurants, courses, colis) — **frontend**.
Aucun backend, aucun Firebase : les données sont des mocks écrits en dur dans les dossiers
`data/` de chaque module. Le module communication suit déjà le pattern repository :
il peut basculer sur une vraie API REST (Dio) sans toucher aux écrans.

L'application est découpée en **5 modules** (un par membre de l'équipe), chacun avec son
onglet dans la barre de navigation et ses écrans : voir « Navigation : 5 modules ».

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
| Notification push | bouton 📣 du centre de notifications, ou « Tester une notification » dans les réglages |
| Messagerie | chaque message reçoit une réponse automatique (statuts lu, « écrit… ») |

## Dépendances

| Package | Rôle |
| --- | --- |
| `go_router` | navigation, barre du bas (StatefulShellRoute), transitions personnalisées |
| `google_fonts` | Poppins (titres) et Inter (texte) |
| `flutter_animate` | cascades d'apparition, micro-interactions |
| `shimmer` | squelettes de chargement |
| `lottie` | animations bienvenue / commande confirmée / panier vide |
| `dio` | client HTTP des dépôts « API » du module 5 (Messages) |

Les animations Lottie (`assets/lottie/`) sont générées par `tool/generate_lottie.py` ;
vous pouvez les remplacer par des fichiers LottieFiles portant les mêmes noms.

## Navigation : 5 modules

Parcours : Splash → Onboarding → Connexion → Accueil (onglet **Explorer**).

| # | Onglet | Route (écran principal) | Dossier | Fichier de routes |
| --- | --- | --- | --- | --- |
| 1 | Compte | `/auth` (profil) | `features/auth` (+ `profile`, `admin`) | `auth/auth_routes.dart` |
| 2 | Explorer | `/explore` (accueil) | `features/catalog` | `catalog/catalog_routes.dart` |
| 3 | Commandes | `/orders` (mes commandes) | `features/orders` | `orders/orders_routes.dart` |
| 4 | Livraison | `/delivery` (envoi de colis) | `features/delivery` | `delivery/delivery_routes.dart` |
| 5 | Messages | `/communication` (conversations) | `features/communication` | `communication/communication_routes.dart` |

- **Configuration centrale** : `lib/core/config/modules_config.dart` décrit chaque module
  (numéro, nom, label, icônes, route, couleur, écran principal) et ses écrans prévus.
  La barre de navigation et les routes en sont générées.
- **Barre de navigation** (Material 3) : icône qui rebondit, trait coloré qui glisse,
  badges animés (articles du panier sur Commandes, messages non lus sur Messages).
  Chaque onglet s'ouvre sur l'écran principal de son module et garde son historique.
- **Plein écran** (`fullScreen: true`) : splash, connexion, détail produit, confirmation,
  suivi, chat… s'ouvrent par-dessus la barre. Les autres écrans restent dans leur onglet.
- **Écrans prévus non développés** (ex. `/orders/order-detail`, espace livreur) :
  ils affichent « En cours de développement par le Module X » avec la route et le
  fichier à modifier.

### Remplacer un placeholder par un vrai écran

Déclarez la page dans le fichier de routes du module, avec l'identifiant de l'écran
défini dans `modules_config.dart` :

```dart
// lib/features/orders/orders_routes.dart
screens: {
  'order-detail': (context, state) => const OrderDetailPage(),
},
```

La route du placeholder ouvre alors la vraie page.
Une route avec paramètre (ex. `tracking/:id`) se déclare dans `extraRoutes` avec
`ModuleRoutes.route(...)`. Pour ajouter un écran prévu, ajoutez un `PlannedScreen`
dans `modules_config.dart` ; `test/modules_config_test.dart` vérifie la cohérence.

Les chemins utilisés dans le code passent toujours par `AppRoutes`
(`core/routes/app_routes.dart`) ou `CommunicationRoutes`, jamais par des chaînes en dur.

## Architecture

```
lib/
├── core/
│   ├── config/      modules_config.dart (les 5 modules), AppConfig (mock ou API)
│   ├── constants/   couleurs, tailles, durées, chemins d'assets
│   ├── network/     client Dio partagé, ApiException
│   ├── routes/      app_router (assemblage), module_routes, app_routes, transitions
│   ├── session/     session simulée (connecté / déconnecté)
│   ├── theme/       thème Material 3 clair/sombre, palette, ThemeController
│   ├── utils/       formatage (prix, dates), validateurs de formulaires
│   └── widgets/     main_shell (barre des modules), placeholder_page,
│                    et composants réutilisables (boutons, champs, shimmer…)
├── features/        chaque module déclare ses écrans dans <dossier>_routes.dart
│   ├── auth/        module 1 : splash, onboarding, connexion, inscription, OTP
│   ├── profile/     module 1 : profil, adresses, paiements, langue
│   ├── admin/       module 1 : tableau de bord admin (démo)
│   ├── catalog/     module 2 : accueil, recherche, restaurants, menu, produit, favoris
│   ├── orders/      module 3 : panier, validation, confirmation, historique
│   ├── delivery/    modules 3 et 4 : suivi (carte simulée), envoi de colis
│   └── communication/  module 5 : avis, notifications, messagerie
└── main.dart
```

Chaque module suit la même organisation : `data/` (mocks), `models/`,
`presentation/` (`pages/`, `widgets/`, `controllers/`).

L'état partagé (panier, commandes, favoris, profil, thème) repose sur de simples
`ChangeNotifier` écoutés avec `ListenableBuilder`, sans package externe. Pour brancher
un vrai backend, il suffira de remplacer les classes `*MockData` par des repositories
et, si besoin, ces contrôleurs par Provider, Riverpod ou Bloc.

## Module 5 (Messages) : avis, notifications, messagerie

Toutes les routes commencent par `/communication` (voir `communication_routes.dart`) :

| Écran | Route |
| --- | --- |
| Avis d'un restaurant (résumé, filtres, tri) | `/communication/reviews/:restaurantId` |
| Donner un avis | `/communication/write-review?restaurantId=…&orderId=…` |
| Modifier un avis | `/communication/write-review?reviewId=…` |
| Mes avis | `/communication/my-reviews` |
| Modération (admin) | `/communication/moderation` |
| Centre de notifications | `/communication/notifications` |
| Réglages des notifications | `/communication/notification-settings` |
| Conversations (écran principal de l'onglet) | `/communication` |
| Conversation (plein écran) | `/communication/chat/:conversationId` |

Organisation (pattern repository) :

```
features/communication/
├── data/
│   ├── reviews/, notifications/, chat/   interface + implémentation API (Dio) + mock
│   ├── mock/communication_mock_data.dart réponses « serveur » au format JSON
│   └── communication_repositories.dart  choisit mock ou API selon AppConfig
├── models/          Review, RatingSummary, AppNotification, NotificationSettings,
│                    Conversation, ChatMessage, ChatEvent (fromJson / toJson)
└── presentation/    controllers/, pages/, widgets/
```

Passer sur l'API réelle :

```bash
flutter run --dart-define=USE_MOCK=false --dart-define=API_BASE_URL=https://votre-api/v1
```

Les dépôts API acceptent une réponse brute (`[...]`) ou enveloppée (`{"data": ...}`).
Le temps réel (notifications, messages) se fait par polling (`/notifications?since=`,
`/chat/events?since=`) ; il peut être remplacé par Firebase Cloud Messaging ou un WebSocket
sans modifier les écrans. Les photos d'avis passent par une galerie simulée, à remplacer
par `image_picker` quand le téléversement sera disponible.

## Tests

```bash
flutter analyze
flutter test
```

- `cart_controller_test.dart` : calculs du panier et codes promo ;
- `lottie_assets_test.dart` : les 3 animations se chargent ;
- `modules_config_test.dart` : cohérence de `modules_config.dart`, des fichiers de
  routes des modules et des chemins `AppRoutes` / `CommunicationRoutes` ;
- `module_shell_test.dart` : démarrage, écran principal de chaque onglet, badge du
  panier, écrans plein écran, placeholder ;
- `screens_smoke_test.dart` : toutes les routes (pages de module, écrans prévus,
  écrans avec paramètres) s'affichent sans erreur ni débordement
  (petit et grand téléphone, clair et sombre) ;
- `navigation_flow_test.dart` : parcours complet accueil → restaurant → produit →
  panier → paiement → confirmation → suivi ;
- `communication_models_test.dart` : aller-retour JSON des modèles du module communication ;
- `communication_repositories_test.dart` : dépôts mock et dépôt API (Dio simulé) ;
- `communication_flow_test.dart` : chat, notifications (bannière, glisser, annuler) et avis.
