# TaskMaster

Flutter task manager with calendar board, contacts, subtasks, comments, and offline-first persistence.

## Prerequisites

- Flutter SDK
- Android SDK (API 36) with platform-tools
- JDK 17
- USB debugging enabled on the Android device

## Build & Run (Linux)

```bash
# Debug build + install on connected device
flutter build apk --debug
adb install -r build/app/outputs/flutter-apk/app-debug.apk
adb shell am start -n pl.taskmaster.taskmaster/.MainActivity

# Or hot-reload directly
flutter run -d android
```

## Build (Release APK)

```bash
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk
```

Release builds use the debug signing key by default. For production, configure a release keystore in `android/app/build.gradle.kts`.

## Run Tests

```bash
flutter test
flutter analyze
```
