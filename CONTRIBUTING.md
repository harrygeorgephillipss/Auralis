# Contributing to Auralis

Auralis is an early-stage Android-first Flutter application. Contributions should be small, reviewable and tested.

## Before opening a pull request

- Explain the problem and intended behavior.
- Include screenshots or a screen recording for UI changes.
- Add tests for behavior changes.
- Run the same checks as CI:

  ```bash
  flutter pub get
  dart format --output=none --set-exit-if-changed lib test
  flutter analyze lib test
  flutter test --reporter expanded
  ```

- Do not add provider integrations that bypass authorization, DRM, subscriptions or access restrictions.
- Do not commit secrets, downloaded copyrighted media or generated signing keys.
- Do not edit files inside `upstream/mornye/` as part of ordinary Auralis feature work. Propose upstream updates separately and update the pinned submodule commit deliberately.

## Development setup

Install the Flutter SDK version pinned in the workflow (3.47.8), Android Studio and the Android SDK. Then run:

```bash
flutter doctor
flutter pub get
flutter analyze lib test
flutter test
```

The repository currently contains a Flutter UI shell, not a complete music player. Playback, providers, downloads and the Android host are still integration work.
