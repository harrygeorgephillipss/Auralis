# Auralis release checklist

## Automated checks

- [ ] Flutter dependency resolution succeeds from a clean checkout with recursive submodules.
- [ ] Dart formatting check passes.
- [ ] `flutter analyze lib test` passes without warnings.
- [ ] `flutter test` passes.
- [ ] Android preparation script passes and sets minSdk 28, compileSdk 36 and targetSdk 36.
- [ ] Android manifest includes the audio_service media playback service, media button receiver and required foreground-service permissions.
- [ ] Release APK builds and the artifact can be downloaded and opened as a ZIP archive.
- [ ] Dependency and licence inventory is reviewed for the exact release lockfile.

## Device validation before public release

Test on at least one Android 9 (API 28) device and one recent Android device:

- [ ] Fresh install, first launch and launcher icon.
- [ ] Local audio import, app restart, playback and deletion.
- [ ] Playback while screen is locked and while another app is foregrounded.
- [ ] Notification pause, resume, previous, next and stop controls.
- [ ] Headphone unplug and audio-focus interruption behavior.
- [ ] Network unavailable, slow search, invalid preview URL and stream failure.
- [ ] Unsupported equalizer effect route: app must continue playing without crashing.
- [ ] App process killed during playback, then relaunch and library recovery.
- [ ] Low storage and large audio file import.
- [ ] Android 13+ notification behavior and Android 14+ foreground-service restrictions.

## Release scope disclosure

Do not describe Auralis 0.4.0 as a full provider/download client. The Mornye Rust extension runtime, provider extension installation, authorized offline download queue, and Mochy Kotlin providers are not integrated in this release.
