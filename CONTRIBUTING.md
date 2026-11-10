# Contributing to Auralis

Auralis is in its initial scaffold stage. Contributions should focus on small, reviewable changes.

## Before opening a pull request

- Explain the problem and intended behavior.
- Include screenshots for UI changes.
- Add tests for behavior changes.
- Run `dart format .` and `flutter analyze`.
- Do not add provider integrations that bypass authorization, DRM, subscriptions or access restrictions.
- Do not commit secrets, downloaded copyrighted media or generated signing keys.

## Development setup

Install Flutter stable and Android SDK, then run:

```bash
flutter doctor
flutter pub get
flutter analyze
flutter test
flutter run
```
