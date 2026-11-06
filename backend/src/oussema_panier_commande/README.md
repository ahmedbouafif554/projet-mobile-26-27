# Module 3 (Oussema) — Panier & Commandes 🛒📦

Module complet et indépendant développé pour la gestion avancée du **Panier** et des **Commandes** (Module N°3) de la plateforme **SuperFaster**, 100% aligné avec le front-end Flutter (Front Office & Back Office).

---

## 📁 Architecture du Module

```
backend/src/oussema_panier_commande/
├── index.js                     # Point d'entrée principal (exporte routeurs et services)
├── domain/                      # Règles métier, constantes et calculs
│   ├── panier.constants.js      # Frais de service, fusion d'articles, codes promotionnels
│   ├── commande.constants.js    # Statuts de commande, transitions autorisées, permissions par rôle
│   └── livraison.constants.js   # Statuts de livraison, frais kilométriques, part du livreur
├── services/                    # Logique métier avancée
│   ├── panier.service.js        # CRUD panier SQLite, mergeKey, validation mono-restaurant, totaux
│   ├── commande.service.js      # Cycle de vie, machine d'états, intégrité des prix, timeline, stats
│   ├── livraison.service.js     # Dispatching Haversine, télémétrie GPS, sécurisation OTP
│   └── geo.utils.js             # Formule de Haversine et calcul d'ETA
├── controllers/                 # Gestionnaires de requêtes HTTP Express
│   ├── panier.controller.js     # Contrôleur Panier (CRUD /cart/items et /cart)
│   ├── commande.controller.js   # Contrôleur Commandes (CRUD /orders)
│   └── livraison.controller.js  # Contrôleur Livraisons & Télémétrie
└── routes/                      # Définition des routes de l'API REST
    ├── panier.routes.js         # Routes /api/cart/items et /api/cart
    ├── commande.routes.js       # Routes /api/orders et /api/oussema/commandes
    └── livraison.routes.js      # Routes /api/deliveries et /api/oussema/livraisons
```

---

## 🌟 Fonctionnalités Avancées Implémentées (Module 3)

### 1. Gestion Complète du Panier (`PanierService`)
- **CRUD Persistant en SQLite** : table `cart_items` pour conserver le panier d'un client entre ses sessions.
- **Conformité stricte avec Flutter `CartItem`** : format JSON 100% compatible avec `CartItem.fromJson(json)` et `Product.fromJson(json)`.
- **Fusion automatique (`mergeKey`)** : les ajouts d'un même produit avec les mêmes options et la même note incrémentent la quantité au lieu de dupliquer la ligne.
- **Règle métier mono-restaurant** : empêche d'ajouter des produits de plusieurs restaurants dans le même panier (renvoie HTTP 409 Conflict sauf si `replace: true`).
- **Calculs dynamiques (`CartTotals`)** :
  - Sous-total automatique
  - Frais de livraison tirés du restaurant
  - Frais de service (5 % du sous-total, clampé entre 0,49 € et 1,99 €, identique à Flutter)
  - Réductions par code promo (`SUPER10`, `BIENVENUE`, `LIVRAISON`)

### 2. Cycle de vie & Machine d'États des Commandes (`CommandeService`)
- **CRUD complet des commandes** : Création (`POST /orders`), Lecture unitaire et liste (`GET /orders`), Mise à jour (`PUT /orders/:id`), Suppression (`DELETE /orders/:id`).
- **Filtres avancés** : par utilisateur (`?userId=u-client-1`), par restaurant (`?restaurantId=rest_demo`), par statut.
- **Machine d'états stricte** :
  `pending` ➔ `accepted` / `confirmed` ➔ `preparing` ➔ `ready` ➔ `delivering` ➔ `delivered` (ou `cancelled` ➔ `refunded`).
- **Synchronisation avec la cuisine (Kanban)** : support de l'avancement d'étape et des rôles autorisés.
- **Création automatique de la livraison liée** : dès validation de la commande, création automatique d'une course de livraison avec code OTP à 4 chiffres.
- **Historique & Traçabilité (Timeline)** : horodatage et archivage de chaque changement de statut dans `order_events`.
- **Annulation et Remboursement** : points d'entrée dédiés (`/api/orders/:id/cancel` et `/api/orders/:id/refund`) avec gestion des motifs.
- **Métriques et statistiques** : Chiffre d'affaires, panier moyen et répartition par statut (`/api/oussema/commandes/stats`).

---

## 🚀 Endpoints de l'API REST

### Panier (`/api/cart/items` et `/api/cart`)

| Méthode | Route | Description |
| :--- | :--- | :--- |
| `GET` | `/api/cart/items` | Lister les articles du panier du client connecté |
| `POST` | `/api/cart/items` | Ajouter un article au panier (fusion si identique) |
| `GET` | `/api/cart/items/:id` | Récupérer un article du panier |
| `PUT` | `/api/cart/items/:id` | Modifier la quantité ou les options d'un article |
| `DELETE` | `/api/cart/items/:id` | Supprimer une ligne du panier |
| `DELETE` | `/api/cart/items` | Vider complètement le panier |
| `GET` | `/api/cart/totals` | Récupérer les totaux (sous-total, livraison, frais de service, promo) |

### Commandes (`/api/orders` et `/api/oussema/commandes`)

| Méthode | Route | Description |
| :--- | :--- | :--- |
| `GET` | `/api/orders` | Lister les commandes (`?userId=`, `?restaurantId=`, `?status=`) |
| `POST` | `/api/orders` | Passer une commande (calcul certifié et vidage panier) |
| `GET` | `/api/orders/:id` | Détail d'une commande (avec articles, options, adresse, timeline) |
| `PUT` | `/api/orders/:id` | Mettre à jour une commande (champs généraux ou statut) |
| `DELETE` | `/api/orders/:id` | Supprimer une commande |
| `PATCH` | `/api/orders/:id/status` | Changer le statut (validé par la machine d'états) |
| `POST` / `PATCH` | `/api/orders/:id/cancel` | Annuler la commande avec motif |
| `POST` / `PATCH` | `/api/orders/:id/refund` | Rembourser la commande |
| `GET` | `/api/orders/:id/timeline` | Historique des événements de la commande |
| `GET` | `/api/orders/:id/tracking` | Données de suivi en direct pour l'écran de tracking |
| `GET` | `/api/oussema/commandes/stats` | Statistiques globales ou par restaurant |

### Livraisons (`/api/deliveries` et `/api/oussema/livraisons`)

| Méthode | Route | Description |
| :--- | :--- | :--- |
| `GET` | `/api/deliveries` | Lister les livraisons (`?courierId=`, `?status=`) |
| `GET` | `/api/deliveries/:id` | Détail d'une livraison |
| `GET` | `/api/deliveries/:id/tracking` | Coordonnées GPS + timeline en 5 étapes |
| `POST` | `/api/oussema/livraisons/:id/auto-dispatch` | Assignation automatique au livreur le plus proche |
| `PATCH` | `/api/deliveries/:id/status` | Changement de statut (validation OTP pour `delivered`) |
| `POST` | `/api/oussema/livraisons/couriers/:id/location` | Télémétrie GPS du livreur |

---

## 🧪 Tests Automatisés

Le module dispose d'une suite de tests complète validant l'ensemble des scénarios :
```bash
cd backend
npm test
```
Résultat : **100% des tests validés (47/47 tests réussis)**.
