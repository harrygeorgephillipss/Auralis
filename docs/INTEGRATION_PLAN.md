# Source integration plan

## Current technical decision

Mornye is the chosen Flutter/Rust reference implementation because it is closer to Auralis's target architecture than Mochy's native Kotlin UI. Its exact source commit remains pinned at `upstream/mornye`. Do not treat the submodule pin as a completed integration.

Mochy is Android/Kotlin. Reimplement selected interaction patterns in Flutter; do not copy its Android activities or screen classes into the Flutter app. Any later source reuse needs a file-by-file license and provenance review.

## Phase 0 — preserve and audit

- Keep the uploaded ZIP archives unchanged as reference snapshots.
- Record upstream URLs, versions, exact source commits and license notices.
- Inventory direct/transitive dependencies, native libraries, provider extensions and bundled assets.
- Review privacy, telemetry, authentication, provider terms and download behavior.
- Build each upstream project independently before migration.

## Phase 1 — Android foundation (implemented in 0.4.0)

- CI generates and configures the Android host project.
- Minimum Android API is 28 (Android 9); compile and target SDK are 36.
- The manifest declares Flutter embedding v2, the media playback foreground service, media-button receiver and required permissions.
- A monochrome adaptive launcher icon and native launch background are generated from the Auralis mark.
- An API 28 emulator smoke test is part of the Android workflow; physical-device testing remains a release gate.

1. Establish a reproducible Flutter/Android CI toolchain.
2. Add and validate the Android host project and stable Auralis application ID.
3. Build the untouched pinned Mornye app before changing it; record all build failures and toolchain requirements.
4. Inventory Android-relevant pub dependencies and local plugins; exclude unsupported desktop and Apple targets deliberately, not by deleting shared code.
5. Review and gate optional partner SDKs, provider modules and proprietary assets.
6. Integrate the selected app bootstrap and native platform configuration in small commits.

## Phase 2 — application architecture

- Define domain contracts for Track, Album, Artist, Provider, AudioSource, PlaybackState and DownloadTask.
- Keep providers, storage and player implementations behind interfaces.
- Adopt state management and routing only after comparing the pinned upstream choices with a minimal Auralis dependency graph.
- Add logging with secret redaction, cancellation, typed failures and lifecycle handling.

## Phase 3 — UI and customization

- Build the Auralis design system: typography, spacing, surfaces, motion and artwork treatment.
- Implement Home, Explore, Library, Downloads, Now Playing and Settings.
- Add themes, player layouts, artwork treatment and visualizer settings.
- Validate small/large screens, landscape, accessibility font scaling and reduced motion.

## Phase 4 — local playback and library (basic path implemented; deeper coverage pending)

- Local audio import, app-private file copies and SQLite metadata persistence are implemented.
- Background media session, audio-session configuration, interruption handling and a five-band Android equalizer are integrated.
- Queue behavior is currently limited to tracks played in the current session; playlists, history and richer metadata editing remain pending.

- Integrate playback, Android media session, foreground service/notification, audio focus and headset actions.
- Add local file access via Android Storage Access Framework / supported media APIs.
- Implement queue, playlists, metadata, history, favorites and search.
- Test interruption handling, process death, app restart, Bluetooth and wired headsets.

## Phase 5 — authorized providers and downloads

- Port/adapt only providers whose terms allow the product's intended use.
- Treat extensions as untrusted code/data; define permissions, signing, update validation and isolation.
- Implement pause/resume, cancellation, integrity checks, storage policy and source attribution.
- Never bypass DRM, subscriptions, authentication or other access controls.
- Preserve the source bytes and report only verified codec/quality metadata.

## Phase 6 — release readiness

- Unit tests and Flutter analysis run in CI; Android release APK build and API 28 emulator launch smoke test are being validated.
- Complete real-device checks for audio focus, notification controls, file import, process death and supported formats.
- Complete full transitive dependency, provider terms, privacy and licence audits before public distribution.
- Publish notices, SBOM/dependency inventory and reproducible build steps.
- Produce signed builds only with owner-controlled signing material.

## Explicit non-goals

- No claim that Auralis is a working streaming/downloading app until providers and playback are implemented and tested.
- Do not describe 0.4.0 as a complete provider/download client; provider and authorized download integration remains pending.
- No redistribution of bundled partner SDKs or proprietary artwork without explicit rights.
