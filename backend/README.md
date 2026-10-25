# SuperFaster — Backend API

REST API for the **SuperFaster** delivery platform (food, groceries & parcels).

## Stack
- **Node.js** + **Express**
- **JWT** authentication
- Ready to connect to any SQL/NoSQL database

## Getting Started

```bash
cd backend
npm install
cp .env.example .env   # fill in your values
npm run dev            # starts on http://localhost:3001
```

## Endpoints

| Method | Route | Description |
|--------|-------|-------------|
| POST | `/api/auth/register` | Register a new user |
| POST | `/api/auth/login` | Login & receive JWT |
| GET | `/api/users` | List all users |
| GET/PUT/DELETE | `/api/users/:id` | User CRUD |
| GET | `/api/restaurants` | List restaurants |
| GET/POST/PUT/DELETE | `/api/restaurants/:id` | Restaurant CRUD |
| GET | `/api/products` | List products |
| GET | `/api/orders` | List orders |
| POST | `/api/orders` | Create an order |
| GET | `/api/deliveries` | List deliveries |
| GET | `/health` | Health check |

## Project Structure

```
backend/
├── src/
│   ├── app.js              # Express entry point
│   ├── routes/             # Route definitions
│   ├── controllers/        # Business logic (to implement)
│   ├── middleware/         # Auth middleware, etc.
│   ├── models/             # DB models (to implement)
│   └── config/             # Configuration helpers
├── .env.example
├── .gitignore
└── package.json
```
