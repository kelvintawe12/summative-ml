Ranch Conservation Predictor (Flutter)

This folder contains a minimal Flutter app to call the Ranch Conservation Predictor API.

Files created:
- `pubspec.yaml` — declares dependencies (`http`, `cupertino_icons`).
- `lib/main.dart` — main application UI and network call.

Quick start

1. Install Flutter on your machine: https://flutter.dev/docs/get-started/install
2. Open a terminal in this folder and (only first time) run:

```powershell
flutter create .
```

This generates platform-specific files (`android/`, `ios/`, etc.).

3. Get packages:

```powershell
flutter pub get
```

4. Run the app (choose an emulator or device):

```powershell
flutter run
```

Notes

- The app posts to `https://summative-ml-hliu.onrender.com/predict`. Make sure the API is reachable from the device/emulator.
- To create a release build:
  - Android: `flutter build apk --release`
  - iOS: `flutter build ios` (on macOS)

If you want, I can:
- Add icons, flavors, or CI config.
- Create a full Flutter project skeleton (with `android/ios/web` files) and test instructions.
