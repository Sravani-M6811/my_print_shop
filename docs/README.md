# MY PRINT SHOP

A full-featured **custom print shop** mobile & web app built with **Flutter**, backed by **Firebase** (Auth, Cloud Firestore, Cloud Storage) with an optional **Node.js/Express + SQLite** admin backend.

Users can browse a product catalogue (sarees, dress materials, t-shirt prints, mugs, posters, embroidery), design their own custom prints (text, fonts, colours, image upload), add items to a cart, check out with address + payment, and track order history — all persisted locally and synced to their Firebase account when signed in.

---

## Features

- **Product catalogue** — categories and products with pricing.
- **Custom design studio** — place & drag text, pick fonts, colours, size, bold; upload a photo/logo (synced to Firebase Storage when signed in).
- **Search** — instant filtering of products by name or category.
- **Shopping cart** — add/remove, quantity steppers, live line totals & grand total.
- **Checkout** — delivery address form + payment method (UPI / Cash on Delivery). Optional Razorpay integration.
- **Orders** — order confirmation screen + full order-details view (items, delivery address, payment, status) and an order history on the profile tab.
- **Authentication** — Firebase phone OTP sign-in, with a guest-browsing mode (orders placed as guest are stored locally and sync on sign-in).
- **Dark / light theme** — brand colour `#6C5CE7`, coherent Material 3 design.
- **Responsive layouts** — adaptive product grids for mobile, tablet, web/desktop.
- **AI assistant** *(optional backend)* — chat with the shop assistant via a local Ollama endpoint.
- **Persistent state** — `provider` + `AppState`; data saved to `shared_preferences` and mirrored to Firestore.

--- 



## Tech Stack

| Layer        | Technology                                            |
|--------------|-------------------------------------------------------|
| Frontend     | Flutter (Dart), Material 3                            |
| State        | `provider` + a single `AppState` `ChangeNotifier`      |
| Auth         | Firebase Authentication (phone OTP)                   |
| Database     | Cloud Firestore (`users/{uid}/orders`)                |
| Files        | Firebase Storage (`custom_designs/{uid}/...`)         |
| Payments     | Razorpay (test key via `--dart-define=RAZORPAY_KEY_ID`)|
| Admin backend| Node.js / Express + SQLite (`backend/server.js`) |

---

## Getting Started

### Prerequisites

- Flutter SDK (`>=3`, Dart `^3.12`)
- A Firebase project (or use the bundled `lib/firebase_options.dart`).
- *(Optional)* Node.js for the admin backend.

### Run the app

```bash
flutter pub get
flutter run
```

Run on a specific platform:

```bash
flutter run -d chrome      # web
flutter run -d <device>    # Android / iOS / desktop
```

### Build

```bash
flutter build apk --release
flutter build web --release
```

---

## Firebase Setup

The project includes ready-made rules:

- `firestore.rules` — secures reads/writes to the signed-in user's own data
  (`users/{uid}/orders`).
- `storage.rules` — allows each user to read/write only their own
  `custom_designs/{uid}/...` folder.
- `firestore.indexes.json` — composite index definitions.
- `firebase.json` — Firebase CLI project configuration.

**Firebase project:** `my-print-shop-7b153` is pre-configured in
`lib/firebase_options.dart`. If you use your own project, replace that file
(via `flutterfire configure`).

> Note: the API key in `firebase_options.dart` is public by design (it is not
> a secret — Firebase security is enforced by the rules files above).

### Enable auth providers

For phone OTP to work, enable **Phone** in
Firebase Console → Authentication → Sign-in method. On web, reCAPTCHA is used
automatically.

---

## Configuring the Admin Backend (optional)

The Node.js backend powers the assistant and provides an admin order view.

```bash
cd backend
npm install
node server.js          # serves on http://localhost:5000
```

- **Android emulator:** the app targets `http://10.0.2.2:5000` by default.
- **Override the backend URL:** `--dart-define=BACKEND_URL=http://<host>:5000`.

### Razorpay (optional)

Pass your public test key at build/run time:

```bash
flutter run --dart-define=RAZORPAY_KEY_ID=rzp_test_1DP5mmOlF5G5ag
```

---

## Project Structure

```
lib/
  main.dart               App entry: Firebase init, theme, app state
  firebase_options.dart   Firebase configuration
  frontend/               Customer app: screens (auth, home, products, design,
                          cart, checkout, orders, profile), models,
                          providers (AppState), services, data, constants,
                          navigation, l10n
  ui/                     Reusable widgets + theme (light/dark, brand #6C5CE7)
  admin/                  Admin screens + admin logic/services
  assets/                 Images & icons
backend/                  Node.js/Express + SQLite admin backend (server.js)
test/                     Dart widget/service tests
docs/                     Documentation and audit reports
```

---

## Testing

```bash
flutter analyze
flutter test
```

---

## Disclaimer

Payment and phone-OTP flows require live Firebase/Razorpay configuration. When
providers or backends are unreachable, the app degrades gracefully: carts and
orders still work locally and sync once a connection is available.
