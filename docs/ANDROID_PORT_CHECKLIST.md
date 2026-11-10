# Android-first Mornye integration checklist

This document records the concrete port boundaries identified in the pinned Mornye 5.3.1 source. The Auralis root app remains a starter shell until these components are deliberately migrated.

## Keep and evaluate

| Concern | Upstream location | Auralis action |
|---|---|---|
| App bootstrap and dependency scope | `lib/main.dart`, `lib/app.dart` | Rebuild bootstrap under Auralis branding; retain only Android-required initialization |
| Playback state and queue | `lib/providers/music_player_provider.dart`, `lib/providers/playback_provider.dart` | Retain after API and lifecycle review |
| Download queue | `lib/providers/download_queue_provider*.dart` | Retain with provider authorization and format verification |
| Local music library | `lib/providers/local_library_provider*.dart` | Retain Android storage access and SAF permission handling |
| Provider / extension manager | `lib/providers/extension_provider*.dart` | Audit extension permissions, source trust and update mechanism |
| Now Playing screen | `lib/screens/now_playing_screen.dart` | Rebuild presentation in Auralis design system; reuse only domain behavior |
| Player widgets | `lib/widgets/mornye_player_layout.dart`, `lib/widgets/mornye_glass_*.dart` | Study interaction patterns; create original Auralis widgets |
| Audio and media controls | `lib/services/music_player_service.dart`, `lib/services/playback_notification.dart`, `lib/services/player_widget_service.dart` | Preserve Android background playback and media-session behavior |
| Native mobile backend | `rust_backend/crates/mobile/` and `scripts/build_rust_backend.sh` | Integrate only after toolchain and FFI boundary review |
| Android host | `android/` | Rebrand application identity and inspect manifest permissions, services and providers |

## Android identity and build constraints

The pinned upstream currently uses:

- Android namespace / application ID: `com.zarz.mornye`
- Compile SDK: 37
- Target SDK: 37
- Android Gradle Plugin: 9.5.0
- Kotlin Android plugin: 2.4.21
- Android NDK: 30.0.16248370
- Flutter version pin: 3.47.8
- Rust backend build script: `scripts/build_rust_backend.sh`

Auralis must choose its own stable application ID before release (for example, a reverse-domain identifier controlled by the project owner). Changing the ID requires updating Kotlin package paths, manifest references, deep-link schemes, notification/channel identifiers where applicable, signing configuration and any OAuth redirect registrations. Do not perform a blind global string replacement.

## Components requiring special review

- `third_party/`: local plugin forks and native libraries; inspect each license and platform implementation.
- `third_party/mornye_discord/sdk/`: contains a Discord partner SDK AAR. Do not redistribute or enable it in Auralis unless the required rights and project credentials are confirmed.
- `rust_backend/vendor/`: vendored Rust crates; retain notices and verify patch provenance.
- FFmpeg / FFmpegKit: preserve LGPL notices and comply with the selected build configuration.
- Extension downloads: treat packages and metadata as untrusted; enforce source allowlists or signatures and never bypass provider restrictions.
- Android storage: use scoped storage / Storage Access Framework flows rather than broad filesystem access without a justified policy basis.

## Build gate

Before merging the upstream app into the Auralis root:

1. Check out the pinned submodule recursively.
2. Install Flutter 3.47.8, matching Dart SDK, Android SDK 37, NDK 30.0.16248370, Java and Rust toolchain required by upstream.
3. Build the untouched upstream Android app first and record failures.
4. Disable/remove desktop-only plugin declarations only after confirming they are not needed by shared code.
5. Rebrand Android package identity and deep links in a dedicated commit.
6. Migrate the upstream app in staged commits, preserving tests and notices.
7. Run `flutter analyze`, unit/widget tests, and Android debug/release builds.
8. Verify background playback, notification controls, audio focus, SAF file access, download cancellation and process-death recovery on a physical Android device.

## Current status

- [x] Pin exact Mornye source commit as a Git submodule.
- [x] Record source paths and Android build constraints.
- [ ] Build untouched upstream Android app in CI.
- [ ] Port the Flutter app and required local plugins into Auralis root.
- [ ] Rebrand Android application identity.
- [ ] Apply Auralis UI redesign.
- [ ] Validate playback, library, providers and downloads on-device.
