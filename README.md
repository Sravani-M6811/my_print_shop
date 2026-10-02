# MY PRINT SHOP

A Flutter-based custom printing platform where users can explore products, choose compatible designs, customize their prints, preview the result, and place orders.

## Key Features

* Product catalogue with multiple printing categories
* Category-based design selection
* Custom print design and preview
* Search and product filtering
* Shopping cart and checkout
* Online payment and Cash on Delivery
* Order placement and order history
* Firebase Authentication and Firestore integration
* Admin product and order management
* Responsive Flutter UI for mobile and web
* Node.js/Express backend with SQLite

## Product Categories

* Sarees
* Saree Borders
* T-Shirts
* Mugs
* Posters
* Embroidery
* Cardboard
* Glass Art

## Tech Stack

| Area             | Technology                  |
| ---------------- | --------------------------- |
| Frontend         | Flutter / Dart              |
| UI               | Material 3                  |
| State Management | Provider                    |
| Authentication   | Firebase Authentication     |
| Database         | Cloud Firestore             |
| Backend          | Node.js / Express           |
| Local Database   | SQLite                      |
| Payments         | Razorpay / Cash on Delivery |

## Main Flow

**Product → Design → Customize → Preview → Cart → Checkout → Order**

## Project Structure

```text
lib/        Flutter application
backend/    Node.js / Express backend
test/       Flutter tests
docs/       Project documentation
android/    Android configuration
ios/        iOS configuration
web/        Web configuration
```

## Getting Started

### Flutter

```bash
flutter pub get
flutter run
```

### Run on Web

```bash
flutter run -d chrome
```

### Backend

```bash
cd backend
npm install
node server.js
```

The backend runs locally on port `5000`.

## Testing

```bash
flutter analyze
flutter test
```

## Project Highlights

* Custom printing workflow instead of a standard product-only e-commerce flow
* Firebase-backed customer data and order management
* Separate customer and admin functionality
* Responsive interface for different screen sizes
* Local persistence with backend/cloud synchronization

## Note

Some services such as Firebase Authentication and Razorpay require the corresponding project configuration and credentials to be enabled before use.
