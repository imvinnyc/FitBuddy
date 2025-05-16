# FitBuddy

> **Your all‑in‑one cross‑platform fitness companion built with Flutter**

FitBuddy helps you plan, track & visualize every part of your fitness journey – from calculating calories to discovering nearby gyms. 100% written in **Dart** on the **Flutter** framework, FitBuddy runs natively on **Android** and **iOS** using a single code‑base.

---

## ✨ Features

| Module | What you can do |
| ------ | --------------- |
| **Nutrition Tracker** | • Smart autocomplete powered by *Nutritionix*<br>• One‑tap import of macros (calories, fat, protein, carbs, fiber)<br>• Daily logs saved to Hive & cleaned with a tap<br>• Instant bar‑chart breakdown for any date |
| **Calorie Calculator** | • Uses Mifflin‑St Jeor to compute BMR<br>• Activity multiplier yields personalised maintenance calories<br>• Supports metric & imperial inputs |
| **Workout Tracker** | • Record custom exercises, sets & reps by body‑part<br>• Visualise total volume (sets / reps) per day<br>• Log viewer with inline delete |
| **Workout Builder** | • Generates routines via OpenAI (goal × intensity × duration × body type)<br>• Saves each plan locally for offline reference<br>• Integrated tooltips explaining body‑type & diet jargon |
| **Diet Generator** | • Creates balanced meal plans (Keto, Vegan, Paleo, etc.) matched to goal & body type<br>• Plans are cached in Hive for quick access on the go |
| **Workout Planner** | • Schedule future workouts with date/time<br>• Plans stored locally - no internet required<br>• Quick delete functions |
| **Nearby Gyms** | • Detects GPS with `geolocator`<br>• Opens embedded Google Maps search for “gyms near me” inside a WebView |
| **Exercise Tutorials** | • Fast search suggestions from ExerciseDB<br>• AI‑generated step‑by‑step instructions via OpenAI<br>• Tutorials saved offline for repeat viewing |

All logs & saved plans live locally in **Hive** while AI‑heavy tasks are securely handled by the backend.

---

## 🛠 Tech Stack

- **Flutter 3.x** & **Dart SDK ≥ 3.0**<br>- **Riverpod 2** – scalable state‑management<br>- **Hive + Hive Flutter** – zero‑SQL local persistence<br>- **Go Router** – declarative navigation<br>- **Dio** / `http` – REST & form‑encoded networking<br>- **fl_chart** – rich, animated charts<br>- **Geolocator** – GPS permissions & coordinates<br>- **WebView Flutter** & **flutter_widget_from_html** – embed Google Maps within mobile WebViews<br>- **flutter_typeahead** – lightning‑fast autocomplete UI<br>- **Flutter Toast** – sleek success/error toasts

---

## 🚀 Getting Started

### Prerequisites

| Tool | Minimum Version |
| ---- | --------------- |
| [Flutter SDK](https://docs.flutter.dev/get-started/install) | 3.22 stable |
| Android Studio / Xcode / VS Code | latest |
| A connected device or emulator | |

### 1 · Clone the repository
```bash
git clone https://github.com/imvinnyc/fitbuddy.git
cd fitbuddy
```

### 2 · Install dependencies
```bash
# Get dependencies from pubspec.yaml
flutter pub get
```

### 3 · Run
```bash
# Android / iOS (with an emulator or device attached)
flutter run
```

**Tip:** Use `flutter devices` to list all available targets.

<br>

---

## 🔐 Backend

All external API calls - OpenAI, Nutritionix and ExerciseDB - are proxied through a Django backend that keeps credentials hidden and returns only sanitized JSON to the app.<br><br>👉 **Repo link to backend server:** <https://github.com/imvinnyc/fitbuddy_backend>

If you self‑host the backend, remember to update the base URL inside:<br>
- `lib/main.dart`<br>
- `lib/exercise_tutorial_screen.dart`

---

## 📜 License

Distributed under the **MIT License**. See `LICENSE` for more information.

---

> *Made with 💙 + 🏋️ in Flutter*
