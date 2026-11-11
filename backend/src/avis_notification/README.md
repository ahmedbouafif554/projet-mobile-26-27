# Module 5 — Avis & Notifications ⭐🔔

Backend des écrans Flutter du **Module 5** (hors conversations) :

- **Front office** :
  - avis publiés d'un restaurant, avec le bouton « Utile » ;
  - « Noter ma commande » ;
  - « Mes avis » (modifier, supprimer) ;
  - centre de notifications (lire, tout marquer comme lu, supprimer, annuler une suppression) ;
  - préférences de notifications.
- **Back office** :
  - modération des avis (publier, refuser, supprimer, avis signalés) ;
  - réponses du restaurateur ou de l'admin ;
  - campagnes de notifications (brouillon, programmée, envoi, duplication, taux d'ouverture).

Les réponses ont la forme JSON de `Review.toJson()`, `AppNotification.toJson()` et `NotificationCampaign.toJson()`. Le front passe du mode mock à l'API sans changer d'écran.

## Architecture

```
avis_notification/
├── index.js                     # Routeurs, init du schéma, clear() pour les tests
├── domain/
│   ├── avis.constants.js        # Statuts, limites, messages
│   └── notification.constants.js# Types, audiences, statuts de campagne, canaux
├── data/schema.js               # Tables du module (créées ici, pas dans data/db.js)
├── services/
│   ├── avis.service.js          # Avis : création, modération, réponse, votes, signalements, note du restaurant
│   ├── notification.service.js  # Notifications par destinataire, lu/masqué, préférences
│   ├── campagne.service.js      # Campagnes : CRUD, envoi, programmation, taux d'ouverture
│   └── common.js                # Dates, appelant, droits, propriété d'un restaurant
├── controllers/
└── routes/index.js
```

Le module est monté dans `app.js` **avant** les routes existantes. Sur `/api/users` et `/api/restaurants`, il ne définit que ses sous-routes : `/:id/notifications…` et `/:id/reviews`. Toute autre adresse retombe sur les modules utilisateurs et catalogue. Les routes vides de `empty-modules.routes.js` pour `reviews`, `notifications` et `campaigns` ne sont plus atteintes.

Tables : `reviews`, `review_votes`, `review_reports`, `notifications`, `notification_reads`, `notification_hidden`, `notification_campaigns`, `notification_settings`. Le module écrit seulement `restaurants.rating` et `restaurants.review_count` (recalculés sur les avis publiés) en dehors de ses propres tables.

## Règles métier

### Avis
- Seul un **client** peut écrire un avis, et seulement pour **sa** commande **livrée**, une fois par commande.
- Tout avis créé ou modifié par son auteur part **en modération** (`pending`). Le statut, `helpfulCount` et `reportCount` envoyés par le client sont ignorés.
- Seul l'**admin** publie ou refuse un avis. L'auteur est notifié. À la publication, le restaurateur l'est aussi.
- **Réponse** : réservée à l'admin (signée « Équipe SuperFaster ») et au restaurateur du restaurant (signée de son nom), sur un avis publié. L'auteur de l'avis est notifié de la première réponse.
- **« Utile »** : une seule voix par utilisateur, jamais sur son propre avis. Le `PUT` du front qui envoie `helpfulCount + 1` est traité comme ce vote.
- **Signalement** : un par utilisateur. `reportCount` sert de priorité de modération.
- **Visibilité** :
  - sans compte : avis publiés seulement ;
  - client : avis publiés et les siens ;
  - restaurateur : avis publiés et tous ceux de son restaurant ;
  - admin : tout.
  
  Un avis non visible répond 404.
- La note et le nombre d'avis du restaurant sont recalculés à chaque publication, refus, modification ou suppression.

### Notifications
- Une notification est **personnelle** (`userId`) ou **envoyée à tous** (`userId: null`), dans ce cas limitée à une audience : `all`, `clients`, `couriers` ou `restaurants`.
- L'état **lu** et la **suppression** d'une notification envoyée à tous sont propres à chaque destinataire : supprimer la masque pour soi seulement. Seul l'admin la supprime pour tout le monde.
- Un utilisateur ne crée des notifications **que pour lui-même**. C'est le cas de la confirmation de commande créée par le front, et de la restauration après « Annuler » : elle garde le même `id` et la même date. L'admin peut écrire à n'importe qui ou à tous.
- `route` doit être un chemin de l'application (`/orders/123`).
- **Préférences** : les catégories désactivées sont retirées de la liste. Les canaux possibles sont `push`, `email` et `sms`.

### Campagnes (admin)
- Une campagne est en brouillon (`draft`), programmée (`scheduled`, avec une date future obligatoire) ou envoyée (`sent`).
- L'envoi crée une notification `promo` à tous, limitée à l'audience. `recipientCount` est le nombre de comptes actifs visés. `openRate` correspond aux lectures divisées par le nombre de destinataires.
- Une campagne programmée part automatiquement dès que son heure est passée. La vérification se fait à la lecture des campagnes et des notifications.
- Une campagne envoyée ne peut être ni modifiée ni renvoyée (409).

## Endpoints

### Avis

| Méthode | Route | Description |
| --- | --- | --- |
| GET | `/api/reviews` | Liste. Filtres : `restaurantId`, `userId`, `orderId`, `status`, `minRating`, `reported=true`, `unanswered=true`, `q`, `sort=reports` (admin) |
| POST | `/api/reviews` | Créer un avis (client) |
| GET | `/api/reviews/stats?restaurantId=` | Moyenne, répartition 1 à 5, critères, taux de réponse (+ statuts pour l'admin et le restaurateur) |
| GET | `/api/reviews/:id` | Détail |
| PUT | `/api/reviews/:id` | Auteur : modifier. Admin : modifier ou changer le statut. Autre utilisateur : vote « Utile » |
| DELETE | `/api/reviews/:id` | Auteur ou admin |
| PATCH | `/api/reviews/:id/status` | Admin : `{ status }` |
| PATCH/PUT/DELETE | `/api/reviews/:id/reply` | Réponse publique `{ text }` |
| POST/DELETE | `/api/reviews/:id/helpful` | Vote « Utile » |
| POST | `/api/reviews/:id/report` | Signaler `{ reason? }` |
| GET | `/api/reviews/:id/reports` | Admin : signalements |
| GET | `/api/restaurants/:id/reviews` | Avis d'un restaurant (`?status=approved` côté front office) |
| GET | `/api/restaurants/:id/reviews/stats` | Statistiques d'un restaurant |

### Notifications

| Méthode | Route | Description |
| --- | --- | --- |
| GET | `/api/users/:id/notifications` | Notifications de l'utilisateur. Filtres : `type`, `unread=true` |
| GET | `/api/users/:id/notifications/unread-count` | Nombre de non lues, au total et par type |
| POST/PATCH | `/api/users/:id/notifications/read-all` | Tout marquer comme lu |
| DELETE | `/api/users/:id/notifications/read` | Supprimer les notifications lues |
| GET/PUT | `/api/users/:id/notification-settings` | `{ types: { order: true, … }, channels: ['push', …] }` |
| GET | `/api/notifications` | Admin : toutes (`userId`, `type`, `broadcast`, `campaignId`). Autres : les leurs |
| POST | `/api/notifications` | Créer |
| GET/PUT/DELETE | `/api/notifications/:id` | Détail, modification, suppression ou masquage |
| PATCH/POST | `/api/notifications/:id/read` | Marquer comme lue |

### Campagnes (admin)

| Méthode | Route | Description |
| --- | --- | --- |
| GET/POST | `/api/campaigns` | Liste (`status`, `audience`) et création |
| GET/PUT/DELETE | `/api/campaigns/:id` | Détail (avec `openedCount`), modification, suppression |
| PATCH/POST | `/api/campaigns/:id/send` | Envoi immédiat |

## Tests

```bash
cd backend
npm install
npm run test:module5
```
