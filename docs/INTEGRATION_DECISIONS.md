# Auralis integration decision — Mochy + Mornye

## Decision

Keep Flutter as the single Auralis UI/runtime. Do not embed two complete apps or run two independent playback services. Add provider and download adapters behind Auralis-owned contracts, then migrate capabilities incrementally.

## Source-use policy

- **Mornye:** the existing pinned submodule remains the reference source. Evaluate individual LGPL-compatible modules and their dependency closure. Do not copy its whole app or Rust workspace until the Android build, native dependencies, source obligations and runtime security are understood.
- **Mochy:** its source is GPL-3.0. The initial integration will not copy or link Mochy's Kotlin implementation into the LGPL-3.0 Auralis app. Reimplement provider adapters from independently documented public interfaces and permitted service terms. If GPL code is later incorporated, review the combined distribution licence and source-release obligations before proceeding.
- No provider adapter may bypass DRM, subscriptions, authentication, rate limits or provider restrictions. Offline downloads are exposed only when the source explicitly permits them.

## Runtime ownership

- Auralis owns navigation, library metadata, queue presentation and user preferences.
- One playback service owns audio focus, foreground notification, media session and active playback at a time.
- One download engine owns queue state, pause/resume/cancel and final file verification. Provider adapters resolve sources; they do not write files.
- Persist stable provider IDs and source attribution. Do not persist expiring signed stream URLs, cookies or secret headers.

## Integration sequence

1. Establish provider and download contracts plus duplicate-ID and metadata validation tests.
2. Add one legally permitted provider adapter at a time; test search, cancellation, stream expiry and playback hand-off.
3. Evaluate Mornye's extension runtime as an isolated Android proof of concept. Validate extension permissions, signing/update verification, lifecycle, native libraries and Android 9 compatibility before enabling it.
4. Select a single download implementation after comparing Mornye's queue with provider-specific offline APIs. Avoid duplicate download services.
5. Migrate playlists, favourites, history and downloads without overwriting the existing Auralis SQLite library.
6. Complete dependency/SBOM, licence, privacy and physical-device audits before a public release.

## Current status

The integration branch introduces the first Auralis-owned contracts. It is not yet a completed Mochy provider or Mornye extension integration. The existing local player, iTunes preview search and audio service remain the working baseline.
