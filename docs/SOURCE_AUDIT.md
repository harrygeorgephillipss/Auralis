# Preliminary source audit

Audit performed against the two user-uploaded ZIP archives on 2026-11-10. This is a structural audit, not a full security or dependency-license audit.

## Mochy Music archive

- Archive: `Mochy-Music-Mochy-8.3.2.zip`
- Root: `Mochy-Music-Mochy-8.3.2/`
- Main implementation: Android/Kotlin (`.kt`, Gradle Kotlin DSL, Android resources).
- Top-level license file: GNU GPL version 3.
- Provider/module directories include `modules/api`, `modules/applemusic`, `modules/bridge`, `modules/jiosaavn`, and `modules/monochrome`.
- The project is Android-native. Its screens and Android-specific implementation are not directly reusable as Flutter widgets.

## Mornye archive

- Archive: `Mornye-5.3.1.zip`
- Root: `Mornye-5.3.1/`
- Main implementation: Flutter/Dart (`lib/`, `pubspec.yaml`).
- Native backend: Rust workspace in `rust_backend/`.
- Top-level `LICENSE`: GNU Lesser General Public License version 3.
- `COPYING`: GNU GPL version 3 text included with the distribution.
- The Rust workspace declares `LGPL-3.0-only` in `[workspace.package]`.
- The Flutter dependency list includes Riverpod, GoRouter, SQLite, audio service/playback integrations, extension-related packages, and a broad UI layer.
- The archive contains substantial Android, desktop, and Apple-platform code. Android-only trimming must be dependency-aware.

## Integration conclusion

Mornye is the more suitable technical starting point for an Android-first Flutter app. Mochy's design and interaction ideas should initially be independently reimplemented, not copied from its Kotlin source. If any Mochy code is later copied or adapted, the combined work's licensing must be reviewed; GPL-3.0 obligations may apply to the derivative distribution.

## Not yet verified

- Exact upstream commit hashes and whether each archive exactly matches a tagged release.
- Whether all bundled assets are redistributable under the repository's main license.
- Full transitive dependency license compatibility.
- Provider-specific terms and the legality of each source's streaming/download capabilities.
- Runtime security, telemetry and network behavior.
- Whether the archives build successfully in a clean environment.
