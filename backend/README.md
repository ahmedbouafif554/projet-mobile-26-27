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
Public registration accepts **client** and **courier** only. A courier also gets a profile whose documents stay `pending` until an admin reviews them.

Demo password for the seeded accounts: `demo1234`.
The SQLite database `superfaster` is created on startup if it does not exist (`superfaster_test` is used by the tests).

Copy `.env.example` to `.env`. SQLite needs no host, user or password: `DB_NAME` is the database file name.

| Method | Route | Description |
|--------|-------|-------------|
| POST | `/api/auth/register` | Register a client or a courier (no session yet) |
| POST | `/api/auth/login` | Login. Body: `email`, `password`, optional `role`, optional `space` |
| POST | `/api/auth/verify-otp` | Body: `userId`, `code` (`1234` in demo). Returns a JWT |
| POST | `/api/auth/logout` | Stateless logout |
| POST | `/api/auth/forgot-password` | Always the same response |
| GET/PUT | `/api/auth/me` | Current profile |
| GET | `/api/users?email=` | Lookup used by the app before a token exists |
| POST | `/api/users` | Create a user (`id` may be empty) |
| PUT | `/api/users/:id` | Update profile. Role and status are ignored unless the caller is admin |
| PATCH | `/api/users/:id/role` | Admin only. Becoming a courier creates the courier profile |
| PATCH | `/api/users/:id/status` | Admin only. An admin cannot block themselves |
| GET/POST | `/api/couriers` | Courier profiles. Filter with `?userId=` |
| PATCH | `/api/couriers/:id/documents` | Admin: approve or reject every document |
| GET | `/api/users/:id/addresses` | Addresses of the signed-in user |
| POST/PUT/DELETE | `/api/addresses` | Address CRUD |
| PATCH | `/api/addresses/:id/default` | Set the default address, returns the user's list |
| GET | `/api/users/:id/favorites` | Restaurant ids (profile stats) |
| GET | `/health` | Health check |

Point the Flutter app at this API without editing screens:

```bash
flutter run -t lib/main_front.dart --dart-define=USE_MOCK=false --dart-define=API_BASE_URL=http://localhost:3001/api
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
│   ├── oussema_livraison_commande/  # Module Commandes & Livraisons (voir son README)
│   └── restaurant_catalogue/  # Module Restaurants & Catalogue (voir son README)
├── tests/                     # Un fichier de tests par module
├── .env.example
└── package.json
```
