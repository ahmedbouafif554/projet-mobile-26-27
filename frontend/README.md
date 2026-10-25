# SuperFaster — Frontend (Flutter)

Mobile & web app for the SuperFaster delivery platform.

## Entry Points

| Command | App |
|---------|-----|
| `flutter run -t lib/main_front.dart` | Front Office — clients & livreurs |
| `flutter run -t lib/main_back.dart`  | Back Office  — admin & restaurants |

## Getting Started

```bash
cd frontend
flutter pub get
flutter run -t lib/main_front.dart -d chrome
```

## Project Structure

```
frontend/lib/
├── core/           # App bootstrap, theme, routing, network
├── shared/         # Shared models, repositories, providers
├── front_office/   # Client & courier app
├── back_office/    # Admin & restaurant dashboard
├── dev/            # Dev tools & component gallery
├── main_front.dart # Front office entry point
└── main_back.dart  # Back office entry point
```
