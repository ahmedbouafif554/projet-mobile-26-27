# Module Oussema — Livraison & Commande 📦🛵

Module complet et indépendant développé pour la gestion avancée des **Commandes** et des **Livraisons** de la plateforme **SuperFaster**.

---

## 📁 Architecture du Module

```
backend/src/oussema_livraison_commande/
├── index.js                     # Point d'entrée principal (exporte le routeur et les services)
├── domain/                      # Règles métier et constantes
│   ├── commande.constants.js    # Statuts de commande, transitions autorisées, permissions par rôle
│   └── livraison.constants.js   # Statuts de livraison, frais kilométriques, part du livreur
├── services/                    # Logique métier avancée
│   ├── geo.utils.js             # Formule de Haversine (distance orthodromique), calcul ETA
│   ├── commande.service.js      # Machine d'états, calculs de prix, vérification panier, timeline
│   └── livraison.service.js     # Dispatching intelligent, télémétrie GPS, OTP, rétribution
├── controllers/                 # Gestionnaires de requêtes HTTP Express
│   ├── commande.controller.js   # Contrôleur Commandes
│   └── livraison.controller.js  # Contrôleur Livraisons & Télémétrie
└── routes/                      # Définition des routes de l'API REST
    ├── commande.routes.js       # Routes /api/oussema/commandes
    └── livraison.routes.js      # Routes /api/oussema/livraisons
```

---

## 🌟 Fonctionnalités Avancées Implémentées

### 1. Cycle de vie & Machine d'États des Commandes (`CommandeService`)
- **Transitions d'états strictes** :
  `pending` ➔ `confirmed` ➔ `preparing` ➔ `ready` ➔ `delivering` ➔ `delivered` (ou `cancelled` / `refunded`).
- **Permissions par rôle** : un client ne peut annuler que tant que la commande est `pending`.
- **Calculs et intégrité des prix** : recalcul côté serveur à partir du catalogue produit pour empêcher toute manipulation des prix.
- **Codes promotionnels** (`BIENVENUE`, `PROMO10`, `LIVRAISON`) et livraison gratuite au-delà d'un seuil (35 €).
- **Historique chronologique (Timeline)** : traçabilité de chaque changement d'état avec horodatage, auteur et motif dans la table `order_events`.
- **Création automatique de la livraison liée** : dès qu'une commande est passée, une course est créée en statut `waiting` avec génération d'un code OTP sécurisé.

### 2. Dispatching & Télémétrie GPS des Livraisons (`LivraisonService`)
- **Algorithme de Dispatch Haversine** : calcule la distance réelle en kilomètres entre le restaurant et les livreurs disponibles (`available`), triés par proximité et notation.
- **Auto-Dispatch** : assigne automatiquement le meilleur livreur disponible et bascule son statut à `busy`.
- **Télémétrie GPS en temps réel** : enregistrement des coordonnées GPS du livreur avec tracé dans `courier_locations`, recalcul automatique de la distance restante et de l'heure estimée d'arrivée (ETA).
- **Écran de suivi en direct (Live Tracking)** : structure prête pour Flutter combinant coordonnées GPS (restaurant, livreur, client) et timeline en 5 étapes.
- **Sécurisation de la remise par Code OTP** : le livreur doit valider le code OTP à 4 chiffres généré pour la commande pour finaliser la livraison.
- **Calcul automatique des gains du livreur** : versement de 80% des frais de livraison + 100% des pourboires sur son solde (`total_earnings`), incrémentation de son compteur de courses (`completed_deliveries`), et retour au statut `available`.

---

## 🚀 Endpoints de l'API

### Commandes (`/api/oussema/commandes` ou `/api/orders`)

| Méthode | Route | Description |
| :--- | :--- | :--- |
| `POST` | `/api/oussema/commandes` | Créer une commande (avec panier, adresse, promo) |
| `GET` | `/api/oussema/commandes` | Lister les commandes (`?userId=`, `?restaurantId=`, `?status=`) |
| `GET` | `/api/oussema/commandes/stats` | Métriques globales ou par restaurant (chiffre d'affaires, panier moyen) |
| `GET` | `/api/oussema/commandes/:id` | Détail d'une commande avec articles et timeline |
| `GET` | `/api/oussema/commandes/:id/timeline` | Historique des statuts de la commande |
| `PATCH` | `/api/oussema/commandes/:id/status` | Changer le statut (validé par la machine d'états) |
| `POST` | `/api/oussema/commandes/:id/cancel` | Annuler la commande avec motif |

### Livraisons (`/api/oussema/livraisons` ou `/api/deliveries`)

| Méthode | Route | Description |
| :--- | :--- | :--- |
| `GET` | `/api/oussema/livraisons` | Lister les livraisons (`?courierId=`, `?status=`) |
| `GET` | `/api/oussema/livraisons/:id` | Détail d'une livraison |
| `GET` | `/api/oussema/livraisons/:id/tracking` | Données de suivi en temps réel (GPS + étapes) |
| `GET` | `/api/oussema/livraisons/nearby-couriers` | Trouver les livreurs proches (`?latitude=&longitude=`) |
| `POST` | `/api/oussema/livraisons/:id/auto-dispatch` | Assigner automatiquement le livreur le plus proche |
| `POST` | `/api/oussema/livraisons/:id/assign` | Assigner manuellement un livreur (`courierId`) |
| `PATCH` | `/api/oussema/livraisons/:id/status` | Changer le statut (`picked_up`, `delivered` avec `otpCode`) |
| `POST` | `/api/oussema/livraisons/couriers/:id/location` | Ping GPS du livreur (met à jour position et ETA) |
| `GET` | `/api/oussema/livraisons/couriers/:id/stats` | Statistiques et gains du livreur |

---

## 🧪 Tests Automatisés

Le module possède une suite de tests d'intégration dédiée :
```bash
cd backend
$env:NODE_OPTIONS = "--require c:/Users/USER/Desktop/mobile/projet-mobile-26-27/backend/patch-npm.js"
npx jest tests/oussema-livraison-commande.test.js
```
Résultat : **100% des tests validés**.
