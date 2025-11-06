# Fineer

Fineer is a Flutter-based mobile application designed for internal attendance tracking using geolocation. Built for performance and scalability, Fineer leverages Firebase services to provide real-time data management, making it ideal for teams or organizations seeking a streamlined attendance solution.

This application is currently functional and distributed as an Android APK.

---

## Features

- Geolocation-based check-in and check-out
- Real-time attendance tracking
- Secure user authentication (Firebase Auth & Biometrics)
- Cloud Firestore integration
- Modular architecture prepared for future admin dashboard and reporting
- Local data storage using Shared Preferences and Secure Storage

---

## Tech Stack

| Category | Technology |
|-----------|-------------|
| Framework | Flutter |
| State Management | GetX |
| Backend | Firebase (Auth, Firestore, Storage) |
| Location Services | Geolocator, Geocoding |
| Local Storage | Shared Preferences, Flutter Secure Storage |
| Animation & UI | Lottie, Flutter Animate, Carousel Slider, Convex Bottom Bar |
| Permissions & Device Info | Permission Handler, Device Info Plus |
| Platform | Android (currently functional), iOS (planned) |

---

## Screenshots

_Screenshots coming soon._

---

## Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/loupidd/fineer.git
   
2. Navigate to the project directory:
   ```bash
   cd fineer
   
3. Get the dependencies:
   ```bash
   flutter pub get
   
4. Run the application:
   ```bash
   flutter run
