# Module Restaurants & Catalogue 🍔📋

Backend du **Module 2** de SuperFaster : restaurants (inscription, validation, fiche), catégories de cuisine et produits (menus avec options). Les routes et la forme JSON suivent exactement les dépôts API et les modèles du frontend Flutter (`Restaurant`, `Product`, `Category`), sans rien changer aux écrans.

---

## 📁 Architecture du module

```
backend/src/restaurant_catalogue/
├── index.js                      # Point d'entrée : routeurs, services, init()
├── catalogue.schema.js           # Migration SQLite additive et idempotente
├── domain/
│   ├── catalogue.constants.js    # Statuts, valeurs par défaut, limites, messages
│   ├── catalogue.validation.js   # Validation et normalisation des corps de requête (422)
│   └── catalogue.presenters.js   # Ligne SQL → JSON des modèles Flutter
├── services/
│   ├── access.service.js         # Qui peut voir / gérer un restaurant
│   ├── restaurant.service.js     # Restaurants, statut, catégories liées
│   ├── product.service.js        # Produits, options, disponibilité
│   ├── category.service.js       # Catégories et ordre d'affichage
│   └── sql.utils.js              # INSERT / UPDATE génériques
├── controllers/                  # Gestionnaires Express (fins)
└── routes/                       # /api/restaurants, /api/products, /api/categories
```

Tests : `backend/tests/restaurant-catalogue.test.js` (22 tests).

---

## 🔐 Règles d'accès

| Qui | Restaurants | Produits | Catégories |
| :--- | :--- | :--- | :--- |
| Anonyme / client / livreur | Lecture des restaurants **validés** | Lecture des menus des restaurants validés | Lecture des catégories **actives** |
| Restaurateur | + lecture et modification de **son** restaurant | + gestion du menu de **son** restaurant | Lecture des actives |
| Administrateur | Tout : création, validation, suspension, suppression | Tout (y compris déplacer un produit) | Tout : CRUD et ordre |

- Le restaurant d'un restaurateur est celui dont il est propriétaire (`owner_id`) ou celui rattaché à son compte (`users.restaurant_id`).
- Un restaurant non validé renvoie **404** à ceux qui ne le gèrent pas (les demandes en attente ne sont pas révélées).
- Le frontend renvoie l'objet complet à chaque sauvegarde : les champs réservés à l'admin (`status`, `ownerId`, `isPopular`, `rating`, `reviewCount`, `distanceKm`) envoyés par un restaurateur sont **ignorés**, pas refusés.

## 🏪 Cycle de vie d'un restaurant

`pending` (demande) → `approved` (validé) / `rejected` (refusé) ; `approved` ⇄ `suspended`.

- **Inscription Espace Pro** (`POST /api/restaurants` sans jeton) : `ownerId` obligatoire et doit être un compte restaurateur encore `pending` ; le restaurant est toujours créé `pending`.
- Un restaurateur ne gère **qu'un seul** restaurant (409 sinon).
- **Un restaurant non validé est toujours fermé** (`isOpen = false`). Valider (`PATCH /status`) rouvre le restaurant. Pour bloquer les commandes vers un restaurant en attente, refusé, suspendu ou fermé, le module Commandes doit vérifier `status = 'approved'` et `is_open = 1` à la création d'une commande.

---

## 🚀 Endpoints

### Restaurants (`/api/restaurants`)

| Méthode | Route | Accès | Description |
| :--- | :--- | :--- | :--- |
| `GET` | `/api/restaurants` | Public | Restaurants visibles (`?categoryId=`, `?status=`) |
| `GET` | `/api/restaurants/:id` | Public | Fiche d'un restaurant |
| `GET` | `/api/restaurants/:id/products` | Public | Menu du restaurant |
| `POST` | `/api/restaurants` | Public / restaurateur / admin | Inscription ou création |
| `PUT` | `/api/restaurants/:id` | Restaurateur du restaurant / admin | Modification (fusion avec l'existant) |
| `PATCH` | `/api/restaurants/:id/status` | Admin | `{ "status": "approved" \| "rejected" \| "suspended" \| "pending" }` |
| `DELETE` | `/api/restaurants/:id` | Admin | Supprime le restaurant et son menu |

### Produits (`/api/products`)

| Méthode | Route | Accès | Description |
| :--- | :--- | :--- | :--- |
| `GET` | `/api/products` | Public | Produits visibles (`?restaurantId=`, `?categoryId=`, `?available=true\|false`) |
| `GET` | `/api/products/:id` | Public | Détail d'un produit |
| `POST` | `/api/products` | Restaurateur du restaurant / admin | Création (avec `optionGroups`) |
| `PUT` | `/api/products/:id` | Restaurateur du restaurant / admin | Modification ; changer de restaurant : admin |
| `PATCH` | `/api/products/:id/availability` | Restaurateur du restaurant / admin | `{ "isAvailable": false }` (rupture) |
| `DELETE` | `/api/products/:id` | Restaurateur du restaurant / admin | Suppression |

### Catégories (`/api/categories`)

| Méthode | Route | Accès | Description |
| :--- | :--- | :--- | :--- |
| `GET` | `/api/categories` | Public | Catégories dans l'ordre d'affichage (inactives : admin) |
| `GET` | `/api/categories/:id` | Public | Détail |
| `POST` | `/api/categories` | Admin | Création (placée en dernier) |
| `PUT` | `/api/categories/:id` | Admin | Nom, emoji, couleur, activation |
| `PUT` | `/api/categories/order` | Admin | `{ "ids": [...] }` : nouvel ordre (glisser-déposer) |
| `DELETE` | `/api/categories/:id` | Admin | Retire aussi la catégorie des restaurants et produits |

Codes d'erreur : `401` jeton absent, `403` accès refusé, `404` introuvable, `409` doublon / conflit, `422` données invalides — toujours avec `{ "error": "<message en français>" }`.

---

## 🗄️ Base de données (SQLite)

`catalogue.schema.js` s'exécute au démarrage (`app.js`) et, par sécurité, à la première requête du module. Il est **additif et idempotent** :

- crée `restaurants` et `products` seulement si le schéma commun ne les a pas déjà (mêmes colonnes que le schéma de l'équipe) ;
- ajoute les colonnes du module manquantes (`ALTER TABLE … ADD COLUMN`) — `restaurants` : `status`, `cuisine`, `review_count`, `delivery_minutes`, `delivery_fee`, `min_order`, `distance_km`, `menu_sections` (JSON), `is_popular`, `promo` ; `products` : `section`, `option_groups` (JSON), `is_popular`, `calories` ;
- crée `categories` (remplie avec les 10 catégories du catalogue mock) et `restaurant_categories` (lien restaurant ↔ catégorie, clés étrangères `ON DELETE CASCADE`) ;
- crée les index `restaurants(owner_id)`, `products(restaurant_id)` et `restaurant_categories(category_id)`.

Types SQLite natifs (`TEXT`, `INTEGER`, `REAL`), booléens en `0/1`, dates ISO 8601 en `TEXT`, et contraintes `CHECK` (statut, montants positifs, booléens) comme dans le reste du schéma.

Les colonnes déjà utilisées par le module Commandes (`id`, `name`, `address`, `latitude`, `longitude`, `is_open`, `price`, `restaurant_id`…) ne sont jamais modifiées. Les restaurants déjà présents sont considérés comme validés ; pour les anciennes lignes, `cuisine` et `section` reprennent la valeur de l'ancienne colonne `category`.

---

## 🧪 Tests

```bash
cd backend
npx jest tests/restaurant-catalogue.test.js
```

Résultat : **22 / 22 tests validés** (catégories, cycle de vie des restaurants, droits par rôle, validation, options produits, visibilité, compatibilité avec les données existantes et avec le module Commandes).
