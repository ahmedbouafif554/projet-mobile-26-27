# SuperFaster 🚀

Plateforme de livraison de repas, courses et colis.

## Monorepo Structure

```
projet-mobile-26-27/
├── frontend/    ← Flutter app (clients & livreurs)
└── backend/     ← Node.js + Express REST API
```

## Frontend (Flutter)

```bash
cd frontend
flutter pub get
flutter run -t lib/main_front.dart -d chrome   # Front office (clients/livreurs)
flutter run -t lib/main_back.dart  -d chrome   # Back office  (admin/restaurants)
```

## Backend (Node.js + Express)

```bash
cd backend
npm install
cp .env.example .env
npm run dev   # http://localhost:3001
```

See [`backend/README.md`](backend/README.md) for full API documentation.
