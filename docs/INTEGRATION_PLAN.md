# Source integration plan

## Decision

Use Mornye's Flutter/Dart application as the initial technical base after a deeper module-by-module review. Rework the presentation layer for Auralis rather than shipping Mornye's current interface unchanged.

Mochy is an Android/Kotlin project. Because the target is Flutter, do not attempt to embed its Android activities or copy UI classes wholesale. Reimplement selected interaction patterns and user-facing concepts in Flutter. Only consider isolated platform integrations if there is a clear interface boundary and a license review approves it.

## Phase 0 — preserve and audit

- Keep both uploaded archives unchanged as reference snapshots.
- Record exact upstream repository URLs, versions, commit IDs (where recoverable), authors and license notices.
- Inventory direct and transitive dependencies, native libraries, provider extensions and bundled assets.
- Review privacy, telemetry, authentication, provider terms and download behavior.
- Build each upstream project independently before making modifications.

## Phase 1 — Auralis foundation

- Rebrand package metadata, app label, launcher assets and documentation.
- Retain Mornye's proven Flutter/Rust build integration selectively.
- Remove desktop/iOS-only code and dependencies from the Android-first product only after confirming they are not shared by Android features.
- Create feature boundaries and domain contracts.
- Establish CI for formatting, static analysis, unit tests and Android debug builds.

## Phase 2 — UI redesign

- Build a distinct Auralis design system: typography, spacing, surfaces, motion and artwork treatment.
- Implement Home, Explore, Library, Downloads, Now Playing and Settings.
- Add customization controls for themes, player layouts, artwork, visualizer and motion intensity.
- Test on small, medium and large Android screens and with accessibility font scaling.

## Phase 3 — audio and local library

- Integrate background playback, Android media controls, notification, audio focus and headset actions.
- Implement local file scanning and metadata.
- Add queue, playlists, history, favorites and search.
- Validate lifecycle handling and recovery after process death.

## Phase 4 — providers and downloads

- Port or adapt only provider modules whose terms allow the intended use.
- Add extension permissions, signing/versioning and sandboxing strategy.
- Implement a download queue with pause/resume, integrity checks, storage management and clear source attribution.
- Respect provider authorization, copyright, DRM and access controls.

## Phase 5 — release readiness

- Add automated tests and device matrix.
- Perform security and privacy review.
- Publish license notices, dependency inventory and source attribution.
- Create signed release builds and reproducible build instructions.
