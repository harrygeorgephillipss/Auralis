# Pinned Mornye upstream source

Auralis keeps the reviewed Mornye source pinned as a Git submodule. The current Auralis app selectively uses two MIT-licensed packages from that submodule: the audio_service package and the audioplayers_android fork. It does not embed the full Mornye app or its Rust extension runtime.

- Upstream: https://github.com/mornyeapp/Mornye
- Pinned commit: `e7a8f754a618d28ab0baf88ada3f65ab9d41534a`
- Archive reviewed: `Mornye-5.3.1.zip` supplied in this conversation
- Upstream project version: 5.3.1+167
- Flutter SDK pinned upstream: 3.47.8 (`.fvmrc`)
- Main license: LGPL-3.0; the archive also contains GPL-3.0 text and third-party notices. Audit each component before redistribution.

## Checkout

Clone with submodules:

```bash
git clone --recurse-submodules https://github.com/harrygeorgephillipss/Auralis.git
```

If Auralis is already cloned:

```bash
git submodule update --init --recursive
```

The upstream source lives at `upstream/mornye/`. This pin preserves the reviewed source and makes its history auditable. Auralis currently depends on `upstream/mornye/third_party/audio_service` and overrides `audioplayers_android` with `upstream/mornye/third_party/audioplayers_android`. The full Mornye player, Rust backend, extension manager and download pipeline remain separate and are not integrated. See `THIRD_PARTY_NOTICES.md` for the current component licence scope.

## Why a submodule first

Mornye contains a substantial multi-platform Flutter/Rust project, including vendored native dependencies and platform-specific code. Copying the entire archive blindly into Auralis would import unused desktop/iOS components, obscure upstream attribution, and make license and dependency review harder. Pinning the exact upstream commit provides a reproducible base for a deliberate Android-first port.
