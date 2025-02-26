@echo off

:: Run the build environment script
node build_env.js

:: Build the Flutter web app
flutter build web --release

:: Deploy to your hosting service (example for Firebase)
:: firebase deploy --only hosting 