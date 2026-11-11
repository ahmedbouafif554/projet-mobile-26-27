# SuperFaster — Backend API

REST API for the **SuperFaster** delivery platform (food, groceries & parcels).

## Stack
- **Node.js** + **Express**
- **SQLite** (one local database file, no server or password)
- **JWT** authentication, passwords hashed with bcrypt

## Getting Started

```bash
cd backend
npm install
cp .env.example .env   # JWT secret and database name
npm run dev            # starts on http://localhost:3001
```

## Endpoints — auth & profile

The JSON shapes match the Flutter models (`User`, `Courier`, `Address`).
Every route except signup, login, password reset and `/health` needs `Authorization: Bearer <JWT>`.
Invalid, expired or revoked tokens return **401**; blocked accounts, pending restaurants and unapproved couriers return **403**.

Demo password for the seeded accounts (development only): `demo1234`.

| Method | Route | Description |
|--------|-------|-------------|
| POST | `/api/auth/register` | Client (session opened) or courier (pending, with 3 document photos) |
| POST | `/api/auth/register-restaurant` | Espace Pro signup: owner account + restaurant, both pending |
| POST | `/api/auth/login` | Body: `email`, `password`, optional `role`, `space` |
| POST | `/api/auth/google` | Body: `idToken` (Google Sign-In), optional `role`, `space`. Creates a client account if needed |
| POST | `/api/auth/forgot-password` | Emails a single-use link (30 min). Same answer whether the email exists or not |
| GET/POST | `/api/auth/reset-password` | Web page opened from the email / JSON `{ token, password }` |
| POST | `/api/auth/change-password` | `{ currentPassword, newPassword }`. Revokes other sessions, returns a new token |
| POST | `/api/auth/logout-all` | Revokes every session of the account |
| POST | `/api/auth/verify-otp` | Demo code `1234`, only for a just-created account. Disabled in production |
| GET/PUT | `/api/auth/me` | Current profile |
| GET | `/api/users` | Admin: everything. Others: names only (email/phone hidden except your own) |
| POST/DELETE | `/api/users` | Admin only |
| PUT | `/api/users/:id` | Self or admin. Role, status and points only for admin |
| PATCH | `/api/users/:id/role` · `/status` | Admin only |
| GET/POST | `/api/couriers` | Admin: all. Courier: own profile only |
| GET | `/api/users/:id/addresses` · `/favorites` | Self or admin |
| GET | `/health` | Health check |

Login, Google, OTP: 10 attempts / 15 min per IP + email. Password reset: 5 / hour. Signups: 20 / hour per IP.

## Cart, orders and deliveries (rules enforced by the server)

- The cart always belongs to the signed-in account. Product, price and options are re-read from the database: prices sent by the app are ignored. Options are checked against the product's option groups (required groups, max choices).
- Order totals are recomputed server-side: restaurant delivery fee, service fee 5 % (0,49 € – 1,99 €), promo codes `SUPER10`, `BIENVENUE` (≥ 15 €), `LIVRAISON`. Closed or non-approved restaurant, unavailable product, minimum order, invalid promo → refused.
- Statuses: `pending → accepted → preparing → ready → delivering → delivered`, plus `cancelled` and `refunded`. A restaurant moves its own orders up to `ready`; the courier's delivery moves the order to `delivering` / `delivered`; the admin can do everything.
- The delivery is created when the restaurant **accepts** the order (nearby couriers are notified then). A courier can mark it picked up only once the order is `ready`.
- Cancelling: the client while `pending`, the restaurant up to `ready`, the admin up to `delivering`. The delivery is cancelled and the courier freed.
- Refund (admin): paid orders that are delivered or cancelled. Cash is marked paid on delivery.
- Payment: there is **no payment gateway**. Card / Apple Pay orders are recorded as paid, exactly like the app does today.

## Production checklist

Copy `.env.example` to `.env` and set at least:

- `NODE_ENV=production`, `JWT_SECRET` (≥ 32 random chars, the server refuses to start otherwise)
- `ADMIN_EMAIL` / `ADMIN_PASSWORD`: first admin account (no demo accounts are created in production)
- `PUBLIC_URL` (used in reset emails), `CORS_ORIGINS` (back office web URL), `TRUST_PROXY=true` behind a proxy
- `SMTP_*` + `MAIL_FROM` for password-reset emails (without SMTP the link is only written to the server log)
- `GOOGLE_CLIENT_IDS` for Google Sign-In

Point the Flutter app at this API without editing screens:

```bash
flutter run -t lib/main_front.dart --dart-define=USE_MOCK=false --dart-define=API_BASE_URL=http://localhost:3001/api
# Google Sign-In (Android / iOS) : identifiant client OAuth « Web » (+ « iOS » sur iPhone)
#   --dart-define=GOOGLE_SERVER_CLIENT_ID=xxx.apps.googleusercontent.com --dart-define=GOOGLE_CLIENT_ID=yyy.apps.googleusercontent.com
```

## Project Structure

```
backend/
├── src/
│   ├── app.js                 # Express entry point
│   ├── routes/                # HTTP routes
│   ├── services/              # Auth, users, couriers, addresses
│   ├── domain/                # Roles, validation, JSON shapes
│   ├── data/db.js             # Connexion SQLite, schéma et jeu de démo
│   ├── data/schema.js         # Tables users, couriers, addresses, favorites
│   ├── middleware/            # JWT + mock-token
│   ├── oussema_panier_commande/    # Module 3 : Panier & Commandes (voir son README)
│   └── restaurant_catalogue/  # Module Restaurants & Catalogue (voir son README)
├── tests/                     # Un fichier de tests par module
├── .env.example
└── package.json
```
