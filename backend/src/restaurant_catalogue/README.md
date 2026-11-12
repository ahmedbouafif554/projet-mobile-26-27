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
| `GET` | `/api/restaurants` | Public | Restaurants visibles (`?categoryId=`, `?status=`, `?latitude=&longitude=&radiusKm=` : près de moi) |
| `GET` | `/api/restaurants/:id` | Public | Fiche d'un restaurant (`?latitude=&longitude=` : distance du client) |
| `GET` | `/api/restaurants/:id/products` | Public | Menu du restaurant |
| `POST` | `/api/restaurants` | Public / restaurateur / admin | Inscription ou création |
| `PUT` | `/api/restaurants/:id` | Restaurateur du restaurant / admin | Modification (fusion avec l'existant) |
| `PATCH` | `/api/restaurants/:id/status` | Admin | `{ "status": "approved" \| "rejected" \| "suspended" \| "pending" }` |
| `POST` | `/api/restaurants/:id/geocode` | Restaurateur du restaurant / admin | Relocalise l'adresse avec OpenStreetMap |
| `DELETE` | `/api/restaurants/:id` | Admin | Supprime le restaurant et son menu |

### Produits (`/api/products`)

| Méthode | Route | Accès | Description |
| :--- | :--- | :--- | :--- |
| `GET` | `/api/products` | Public | Produits visibles (`?restaurantId=`, `?categoryId=`, `?available=true\|false`) |
| `GET` | `/api/products/:id` | Public | Détail d'un produit |
| `GET` | `/api/products/lookup/:barcode` | Restaurateurs / admin | Fiche pré-remplie depuis Open Food Facts (rien n'est enregistré) |
| `POST` | `/api/products` | Restaurateur du restaurant / admin | Création (avec `optionGroups`, `barcode`, `nutriScore`, `allergens`) |
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

Codes d'erreur : `401` jeton absent, `403` accès refusé, `404` introuvable, `409` doublon / conflit, `422` données invalides, `502` service externe indisponible, `503` géolocalisation désactivée — toujours avec `{ "error": "<message en français>" }`.

---

## 🌍 API externes (valeur ajoutée)

Les deux services sont **gratuits et sans clé**. Ils sont appelés **uniquement par le serveur** : l'application ne parle qu'à notre API, aucune donnée de client n'est envoyée à l'extérieur, et les réponses sont gardées en cache dans SQLite.

### 1. Géolocalisation des restaurants — OpenStreetMap (Nominatim)

- À la création d'un restaurant, ou quand son adresse change, le serveur demande ses coordonnées GPS à Nominatim (`services/geocoding.service.js`).
- **Règles d'utilisation respectées** : une requête par seconde au plus (file d'attente), User-Agent identifiant l'application, résultat gardé dans `geocode_cache` (une adresse n'est demandée qu'une fois ; une adresse introuvable est redemandée après 7 jours).
- **Le service ne bloque jamais l'enregistrement** : en cas de panne, le restaurant est enregistré avec `locationStatus = "error"` puis relocalisé plus tard (`POST /:id/geocode` ou `npm run geocode:catalogue`). L'appel est fait **hors transaction** pour ne pas bloquer la base.
- Statuts (`locationStatus`) : `pending` (à localiser), `ok`, `not_found`, `error`, `manual` (coordonnées saisies). Seuls `ok` et `manual` sont fiables (`hasLocation`).
- **Près de moi** : `GET /api/restaurants?latitude=…&longitude=…` renvoie la distance réelle (formule de haversine, `services/geo.utils.js`) et le **délai estimé** : délai annoncé par le restaurant (2 premiers km compris) + **3 min par km** au-delà (scooter en ville ≈ 20 km/h). Tri du plus proche au plus loin ; `radiusKm` limite le rayon.

### 2. Fiche produit par code-barres — Open Food Facts

- `GET /api/products/lookup/3017620422003` renvoie une fiche prête à enregistrer : nom, marque et quantité, photo, calories (par portion ou pour 100 g), **Nutri-Score** et **allergènes** (`services/barcode.service.js`).
- Le code-barres est validé avant tout appel : 8, 12, 13 ou 14 chiffres et **clé de contrôle GS1** (somme pondérée 3-1-3… modulo 10).
- Réponses gardées dans `barcode_lookups` (7 jours ; produit inconnu : 1 jour). `404` produit inconnu, `502` service indisponible.
- Les produits enregistrent `barcode` (unique dans un restaurant), `nutriScore` (A à E) et `allergens` : les **14 allergènes à déclaration obligatoire** du règlement UE n° 1169/2011.

### Réglages (variables d'environnement, toutes facultatives)

| Variable | Défaut | Rôle |
| :--- | :--- | :--- |
| `GEOCODING_ENABLED` | `true` (sauf en test) | Active la géolocalisation des adresses |
| `NOMINATIM_URL` | `https://nominatim.openstreetmap.org` | Serveur Nominatim |
| `GEOCODING_COUNTRY` | `fr` | Pays recherchés (vide = monde) |
| `GEOCODING_MIN_INTERVAL_MS` | `1100` | Intervalle minimal entre deux requêtes |
| `OPEN_FOOD_FACTS_URL` | `https://world.openfoodfacts.org` | Serveur Open Food Facts |
| `EXTERNAL_API_TIMEOUT_MS` | `8000` | Délai maximal d'une réponse |
| `EXTERNAL_API_CONTACT` | lien du dépôt GitHub | Contact placé dans l'User-Agent |

Localiser les restaurants existants (par exemple après `npm run seed:catalogue`) :

```bash
npm run geocode:catalogue
```

---

## 🗄️ Base de données (SQLite)

`catalogue.schema.js` s'exécute au démarrage (`app.js`) et, par sécurité, à la première requête du module. Il est **additif et idempotent** :

- crée `restaurants` et `products` seulement si le schéma commun ne les a pas déjà (mêmes colonnes que le schéma de l'équipe) ;
- ajoute les colonnes du module manquantes (`ALTER TABLE … ADD COLUMN`) — `restaurants` : `status`, `cuisine`, `review_count`, `delivery_minutes`, `delivery_fee`, `min_order`, `distance_km`, `menu_sections` (JSON), `is_popular`, `promo` ; `products` : `section`, `option_groups` (JSON), `is_popular`, `calories` ;
- ajoute aussi la localisation (`geo_status`, `geocoded_at`) et, pour les produits, `barcode`, `nutri_score` et `allergens` (JSON) ;
- crée `categories` (remplie avec les 10 catégories du catalogue mock) et `restaurant_categories` (lien restaurant ↔ catégorie, clés étrangères `ON DELETE CASCADE`) ;
- crée les caches des API externes `geocode_cache` et `barcode_lookups` ;
- crée les index `restaurants(owner_id)`, `products(restaurant_id)`, `restaurant_categories(category_id)` et l'index unique `products(restaurant_id, barcode)`.

Types SQLite natifs (`TEXT`, `INTEGER`, `REAL`), booléens en `0/1`, dates ISO 8601 en `TEXT`, et contraintes `CHECK` (statut, montants positifs, booléens) comme dans le reste du schéma.

Les colonnes déjà utilisées par le module Commandes (`id`, `name`, `address`, `latitude`, `longitude`, `is_open`, `price`, `restaurant_id`…) ne sont jamais modifiées. Les restaurants déjà présents sont considérés comme validés ; pour les anciennes lignes, `cuisine` et `section` reprennent la valeur de l'ancienne colonne `category`.

---

## 🧪 Tests

```bash
cd backend
npm test -- tests/restaurant-catalogue.test.js tests/restaurant-catalogue-external.test.js
```

Résultat : **39 / 39 tests validés** — catégories, cycle de vie des restaurants, droits par rôle, validation, options produits, visibilité, compatibilité avec les données existantes et avec le module Commandes, plus les API externes (géolocalisation, cache, pannes, près de moi, code-barres). OpenStreetMap et Open Food Facts sont **simulés** dans les tests : aucun appel réseau.

Côté Flutter : `flutter test test/shared/catalogue_external_test.dart` (modèles, dépôts, « Près de moi », formulaire produit par code-barres).
