# Pinned Mornye upstream source

Auralis uses the Mornye Flutter/Dart application as a candidate technical base. The upstream source is pinned as a Git submodule rather than copied into the Auralis repository in this first integration step.

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

The upstream app lives at `upstream/mornye/`. This pin preserves the reviewed source and makes its history auditable. It does **not** mean the Auralis root Flutter app is already integrated with Mornye: `lib/main.dart` is still the initial Auralis shell. The next integration task is to selectively migrate the Android-relevant Flutter code, required assets, platform plugins and Rust/native pieces, then update the root package manifest and run Android builds.

## Why a submodule first

Mornye contains a substantial multi-platform Flutter/Rust project, including vendored native dependencies and platform-specific code. Copying the entire archive blindly into Auralis would import unused desktop/iOS components, obscure upstream attribution, and make license and dependency review harder. Pinning the exact upstream commit provides a reproducible base for a deliberate Android-first port.
