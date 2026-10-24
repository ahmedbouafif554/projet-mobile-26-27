# SuperFaster — plateforme (front office + back office)

Un seul projet Flutter, deux applications qui partagent le même code :

| Application | Public | Lancement |
| --- | --- | --- |
| **Front office** (mobile) | clients et livreurs | `flutter run -t lib/main_front.dart` |
| **Back office** « Espace Pro » (web) | admin et restaurants | `flutter run -t lib/main_back.dart -d chrome` |

Pas de backend pour l'instant : chaque entité a un dépôt **mock** (données en mémoire,
délai réseau simulé de 300 à 800 ms) et un dépôt **API** (Dio) prêt à être branché :

```bash
flutter run -t lib/main_front.dart --dart-define=USE_MOCK=false --dart-define=API_BASE_URL=https://mon-api/v1
```

Build web : `flutter build web -t lib/main_back.dart -o build/web_back` (idem avec
`main_front.dart`).

## Comptes de démonstration

Mot de passe : n'importe lequel de 6 caractères ou plus (ex. `demo1234`).

| Rôle | E-mail | Application |
| --- | --- | --- |
| Client | `alex.martin@exemple.fr` | front office |
| Livreur | `karim.benali@superfaster.fr` | front office |
| Restaurant | `contact@burgerfactory.fr` | back office (boutons « démo » sur la connexion) |
| Admin | `admin@superfaster.fr` | back office |

Codes promo : `SUPER10` (-10 %), `BIENVENUE` (5 € dès 15 €), `LIVRAISON` (livraison
offerte). Code OTP de l'inscription : `1234`.

## Les 5 modules

| Module | Front office (mobile) | Back office (web) |
| --- | --- | --- |
| **1 · Utilisateurs** | splash, onboarding, inscription + OTP, connexion (client / livreur), mot de passe oublié, profil, modifier le profil, adresses (CRUD), paramètres | utilisateurs : tableau (recherche, filtres, tri, pagination), fiche détaillée, création / modification, blocage, changement de rôle, suppression, export |
| **2 · Catalogue** | accueil (offres, catégories, populaires), liste filtrable des restaurants, fiche restaurant (menu par onglets, panier flottant), fiche produit (options, quantité, note), recherche, favoris | restaurants (validation des inscriptions, suspension, CRUD, fiche), catégories (glisser-déposer, CRUD), produits / « Mon menu » (disponibilité en un clic, CRUD), « Mon restaurant » (ouverture, informations) |
| **3 · Commandes** | panier (quantités, balayage + annuler), paiement (adresse, moyen de paiement, code promo), confirmation animée, historique, détail, suivi en temps réel (plan animé, la commande avance seule), annulation, « recommander » | commandes (filtres, étapes, annulation avec motif, remboursement, commande manuelle), fiche commande (progression, historique, livraison), cuisine du restaurateur (Kanban avec glisser-déposer) |
| **4 · Livraison** | tableau de bord livreur (en ligne / hors ligne, chiffres du jour, gains de la semaine), courses proposées (accepter / refuser), course en cours étape par étape, gains, documents et véhicule | livreurs (validation des justificatifs, CRUD, fiche), livraisons (assignation d'un livreur, étapes, annulation), carte en direct (livreurs qui bougent, trajets animés) |
| **5 · Communication** | avis (étoiles animées, notes détaillées, photos), avis d'un restaurant (répartition, filtres, « utile »), mes avis (modifier / supprimer), notifications groupées par date (balayage), préférences, messagerie (bulles animées, « en train d'écrire… », support) | avis (modération, réponses avec modèles), campagnes push (aperçu, programmation, envoi, duplication), conversations (supervision, signalement, intervention du support ; le restaurateur répond à ses clients) |

Les deux applications partagent les mêmes dépôts : une commande passée dans le
front office, un restaurant validé ou une course assignée dans le back office suivent
les mêmes règles métier (une commande « prête » crée sa course, une livraison terminée
libère le livreur et augmente ses gains, valider un restaurant active son compte…).

## Architecture

```
lib/
├── main_front.dart / main_back.dart   points d'entrée
├── core/                              commun aux deux apps
│   ├── app/          bootstrap (ProviderScope, intl), localisation française
│   ├── auth/         AuthService (session mock) et permissions.dart
│   ├── config/       AppConfig (mock ou API, délai simulé)
│   ├── network/      client Dio (provider), ApiException
│   ├── routing/      transitions de pages, SafeGoRouter
│   ├── theme/        couleurs, tailles, thème Material 3 clair/sombre, mode du thème
│   ├── utils/        formatage intl (prix, dates), validateurs, debouncer
│   └── widgets/      composants génériques (voir ci-dessous)
├── shared/
│   ├── models/       User, Address, Restaurant, Category, Product, CartItem, Order,
│   │                 Courier, Delivery, Review, AppNotification (+ campagnes), Chat,
│   │                 Message — fromJson / toJson / copyWith
│   ├── repositories/ <entité>_repository.dart (interface) + mock_ + api_
│   │                 repository_providers.dart (un provider Riverpod par dépôt)
│   ├── providers/    messagerie partagée (messages, « en train d'écrire… »)
│   ├── mock/         données de démonstration
│   └── widgets/      pastilles de statut des entités (mêmes couleurs partout)
├── front_office/
│   ├── front_app.dart, router/ (chemins, redirect, routeur), shell/ (onglets, badges)
│   ├── shared/       cartes de restaurants, plats, étoiles, quantité
│   └── modules/
│       ├── auth/            module 1
│       ├── catalog/         module 2
│       ├── orders/          module 3
│       ├── courier/         module 4
│       └── communication/   module 5
│       (chaque module : providers/, presentation/pages|widgets/, <module>_routes.dart)
├── back_office/
│   ├── back_app.dart, back_theme.dart
│   ├── router/       chemins, règles d'accès par rôle, routeur (ShellRoute)
│   ├── shell/        sidebar (groupes, compteurs, repliable), topbar (recherche
│   │                 globale, thème, alertes, compte), BoPage (fil d'Ariane)
│   ├── auth/         connexion Espace Pro, inscription d'un restaurant
│   ├── dashboard/    tableau de bord admin / restaurateur
│   ├── account/      mon compte
│   ├── shared/       contrôleur CRUD générique, blocs de mise en page
│   └── modules/      users, catalog, orders, delivery, communication
└── dev/              catalogue des composants (étape 1)
```

### Back office

- **Coque** : sidebar 264 px (80 px repliée, animée, groupée par module, compteurs en
  direct), Drawer sous 600 px, repliée par défaut sur tablette. Topbar : recherche
  globale (commandes, produits, restaurants, utilisateurs, livreurs selon le rôle),
  thème clair / sombre, cloche des alertes, menu du compte.
- **Rôles** : l'admin voit tout ; le restaurateur ne voit que son restaurant (tableau de
  bord, « Mon menu », « Mon restaurant », commandes reçues, cuisine, avis, conversations).
  Les règles d'accès (`back_office/router/back_redirect.dart`) reprennent la définition
  du menu (`shell/back_nav.dart`) : une seule source de vérité.
- **Tableau de bord** : indicateurs avec tendance, ventes sur 7 jours, commandes par
  statut, top restaurants (admin) ou top produits (restaurateur), alertes à traiter,
  dernières commandes. Tout se recalcule après une action (mêmes contrôleurs).

### Composants génériques (`core/widgets`)

| Composant | Usage |
| --- | --- |
| `AppDataTable<T>` | tableau : recherche, filtres, tri, pagination, actions (voir / modifier / supprimer avec confirmation), shimmer, état vide, cartes sur mobile |
| `AppForm` + `showAppForm` / `showAppFormDialog` / `showAppFormPanel` | formulaire de création / modification avec validation, en dialogue ou panneau latéral |
| `AppFormSection`, `AppFormRow`, `AppDropdownField`, `AppSwitchField`, `AppTextField` | champs de formulaire |
| `ConfirmDeleteDialog.show` | confirmation avant suppression |
| `StatusChip` (+ `shared/widgets/status_chips.dart`) | statut coloré |
| `StatCard`, `AnimatedCounter` | statistique avec compteur animé et tendance |
| `ChartCard`, `AppLineChart`, `AppPieChart`, `AppBarChart` | graphiques fl_chart qui se dessinent |
| `PageHeader`, `Breadcrumbs` | titre de page, fil d'Ariane, bouton « Ajouter » |
| `EmptyState`, `AsyncValueView`, `ErrorView` | états vide, chargement, erreur |
| `AppSearchField`, `AppSnackbar`, `AppCard`, `Avatar`, `CityMapPainter` | recherche temporisée, messages, carte, photo ou initiales, plan stylisé |

> **Riverpod 3 :** les widgets non visibles (onglet inactif, page recouverte) sont mis en
> pause. Un widget doit lire directement un `FutureProvider` / `AsyncNotifier` (ou un
> `select` dessus) plutôt qu'un `Provider` intermédiaire qui le « watch », sinon la
> reprise déclenche l'erreur « setState() called during build » (voir
> `front_office/shell/tab_badges.dart`).

### Données mock

27 utilisateurs (tous rôles), 10 restaurants dont 2 demandes d'inscription, 10 catégories,
41 produits avec options, 32 commandes sur 7 jours, 6 livreurs, 27 livraisons, 24 avis,
18 notifications, 5 campagnes, 6 conversations, générés de façon déterministe.

## Tests

```bash
flutter analyze
flutter test
```

86 tests : modèles (JSON), données mock, dépôts mock et API (Dio simulé),
authentification et permissions, formatage, composants, catalogue des composants ;
front office : règles d'accès, parcours (connexion, inscription + OTP, compte, panier →
paiement → confirmation, favoris, recherche, annulation, avis, notifications, messages,
livreur) et test de fumée de tous les écrans ; back office : règles d'accès et menu par
rôle, parcours (connexion, utilisateurs, validation d'un restaurant, rupture de produit,
cuisine, étapes d'une commande, assignation, modération, conversation) et test de fumée
de toutes les pages (admin et restaurateur, 1440 / 820 / 390 px, clair et sombre).

> **Flutter 3.32 :** `fl_chart` est limité à `<1.1.0` (les versions suivantes demandent
> une version plus récente de Flutter).
