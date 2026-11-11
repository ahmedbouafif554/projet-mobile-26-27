# Module 4 (Imed) — Livraison & Livreur 🛵

Backend des écrans Flutter du **Module 4** :

- **Front office livreur** : tableau de bord (en ligne / hors ligne), courses à accepter, course en cours, historique, gains, documents et véhicule.
- **Back office admin** : livreurs (CRUD, justificatifs, dossier scanné, statut), livraisons (assignation, suivi, annulation), carte.

Les réponses ont la forme JSON de `Courier.toJson()` et `Delivery.toJson()` : le front passe du mode mock à l'API sans changer d'écran.

## Architecture

```
imed_livraison_livreur/
├── index.js                      # Routeurs + init du schéma
├── domain/
│   ├── livraison.constants.js    # Statuts front ↔ base, transitions, rémunération
│   └── livreur.constants.js      # Véhicules, statuts, justificatifs, messages
├── data/
│   ├── schema.js                 # Colonnes ajoutées à deliveries + delivery_events, delivery_declines
│   ├── delivery.repository.js    # SELECT avec jointures, mapping Delivery
│   ├── courier.repository.js     # Lecture/écriture couriers + courier_documents
│   └── time.js                   # Dates ISO (UTC)
├── services/
│   ├── livraison.service.js      # Cycle de vie des courses, synchro commande et gains
│   ├── livreur.service.js        # Profil, disponibilité, justificatifs, GPS, gains
│   ├── access.js                 # Droits par rôle
│   └── geo.utils.js              # Haversine et durée estimée
├── controllers/
└── routes/
    ├── livreur.routes.js         # /api/couriers
    └── livraison.routes.js       # /api/deliveries
```

Monté dans `app.js` **avant** les anciennes routes `/api/couriers` et `/api/deliveries` : ce module y répond, et un chemin qu'il ne définit pas retombe sur l'ancien routeur. Alias : `/api/imed/livreurs`, `/api/imed/livraisons`.

Aucun fichier des autres modules n'est modifié. Le module lit et écrit les tables partagées (`couriers`, `courier_documents`, `deliveries`, `orders`, `order_events`) et ajoute seulement des colonnes à `deliveries` (`assigned_at`, `picked_up_at`, `cancel_reason`, libellés de retrait et de dépôt) ainsi que deux tables (`delivery_events`, `delivery_declines`).

## Statuts

| Front (`DeliveryStatus`) | En base | Suivants possibles |
| --- | --- | --- |
| `waiting` | `waiting` | `assigned`, `cancelled` |
| `assigned` | `assigned` | `pickedUp`, `waiting` (livreur retiré), `cancelled` |
| `pickedUp` | `picked_up` | `inTransit`, `delivered`, `cancelled` |
| `inTransit` | `in_transit` / `on_the_way` | `delivered`, `cancelled` |
| `delivered` / `cancelled` | idem (`failed` → `cancelled`) | — |

Les filtres et les changements de statut acceptent les deux écritures (`pickedUp` ou `picked_up`).

## Règles métier

- **Assignation / acceptation** : le livreur doit avoir ses justificatifs validés, être en ligne et n'avoir aucune autre course. Le livreur passe « en livraison », la commande reçoit `courierId`. Si deux livreurs acceptent la même course, le second reçoit 409. L'admin peut réassigner une course déjà assignée (l'ancien livreur est libéré).
- **Récupérée / en route** : la commande passe `delivering`.
- **Livrée** : la commande passe `delivered`, le livreur gagne +1 course et `fee + tip`, puis redevient disponible. Si un `otpCode` est envoyé, il doit être correct.
- **Annulée** : le livreur est libéré, la commande n'est pas annulée. On peut ensuite créer une nouvelle course (`POST /deliveries`).
- **Disponibilité** : passer « disponible » exige des justificatifs validés. Un livreur ne peut pas se mettre hors ligne pendant une course. « En livraison » n'est posé que par une assignation.
- **Justificatifs** : seul l'admin les valide ou les refuse. Un livreur qui envoie un `PUT` ne peut pas se valider lui-même. Un renvoi ou une nouvelle photo repasse la pièce « à vérifier », et le livreur passe hors ligne. Une photo absente du corps n'efface pas la photo enregistrée.
- **Statistiques** : la note, le nombre de courses et les gains sont calculés par le serveur. Les valeurs reçues dans un `PUT` sont ignorées, ce qui évite de compter deux fois une course quand le front renvoie le profil après une livraison.
- **Code de remise (`otpCode`)** : visible par l'admin et par le client de la commande, jamais par le livreur.

## Droits

| Rôle | Lecture | Actions |
| --- | --- | --- |
| admin | tout | tout (CRUD, assignation, annulation, validation, suppression) |
| courier | ses courses et les courses à accepter | accepter, refuser, avancer sa course, remettre « à assigner », son profil, sa position |
| client | les courses de ses commandes | suivi |
| restaurant | les courses de ses commandes | créer la course d'une commande prête |
| sans jeton | lecture, assignation et statut (compatibilité avec les tests du module commandes) | — |

## Endpoints

### Livreurs — `/api/couriers`

| Méthode | Route | Description |
| --- | --- | --- |
| GET | `/` | Liste. Filtres : `userId`, `status` (accepte une liste séparée par des virgules), `vehicle`, `zone`, `documentStatus`, `q` |
| POST | `/` | Créer un profil (inscription ou back office) |
| GET | `/me` | Profil du livreur connecté |
| GET | `/overview` | Admin : effectifs par statut et par véhicule, justificatifs en attente |
| GET | `/nearby?latitude=&longitude=&radiusKm=&limit=` | Livreurs disponibles et validés les plus proches |
| GET | `/:id` | Détail (photos pour l'admin et pour le livreur lui-même) |
| PUT | `/:id` | Modifier le profil (JSON complet de `Courier.toJson()`) |
| DELETE | `/:id` | Admin. Refusé (409) pendant une course |
| PATCH | `/:id/status` | `offline` / `available` / `busy` |
| PATCH | `/:id/documents` | Admin : `{ status, type? }`, pour tous les justificatifs ou un seul |
| GET | `/:id/scan` | Admin : dossier d'identité scanné |
| GET | `/:id/stats` (`/earnings`) | Gains du jour, de la semaine et du mois, 7 derniers jours, course en cours |
| GET | `/:id/deliveries` | Courses du livreur |
| POST/PATCH | `/:id/location` | Position GPS, reportée sur la course en cours |
| GET | `/:id/locations` | Historique du tracé (`deliveryId`, `limit`) |

### Livraisons — `/api/deliveries`

| Méthode | Route | Description |
| --- | --- | --- |
| GET | `/` | Liste. Filtres : `courierId`, `status`, `orderId`, `restaurantId`, `unassigned=true` |
| POST | `/` | Créer la course d'une commande (idempotent : renvoie la course existante en 200) |
| GET | `/available` | Courses à accepter, sans celles que le livreur a refusées |
| GET | `/stats` | Indicateurs du back office |
| GET | `/:id` | Détail |
| PUT | `/:id` | Admin : montants et durée, livreur, statut |
| DELETE | `/:id` | Admin. Le livreur est libéré |
| PATCH/POST | `/:id/assign` | `{ courierId }`. Un livreur peut omettre `courierId` |
| POST | `/:id/accept` | Le livreur connecté accepte la course |
| POST | `/:id/decline` | Le livreur refuse la course |
| POST | `/:id/auto-assign` | Admin : assigne le livreur disponible le plus proche du restaurant |
| PATCH/PUT | `/:id/status` | `{ status, otpCode?, reason?, note? }` |
| GET | `/:id/history` | Historique de la course |
| GET | `/:id/tracking` | Positions, distance et temps restants, étapes |

## Tests

```bash
cd backend
npm install
npm test -- tests/imed-livraison-livreur.test.js
```

Les tests utilisent les jetons `mock-token-<userId>` que le front envoie en mode mock.
