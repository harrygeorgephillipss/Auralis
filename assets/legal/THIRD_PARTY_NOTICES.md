# Third-party notices and licence summary

This file is a practical attribution index, not legal advice or a substitute for the licence texts.

## Auralis-owned code

The Auralis application source in this repository is released under **GNU LGPL-3.0-only**, as stated in the root `LICENSE`.

## Bundled upstream components

| Component | Source | Licence | Use in Auralis |
|---|---|---|---|
| audio_service fork | Mornye pinned submodule, `third_party/audio_service` | MIT | Android media session and notification integration |
| audioplayers_android fork | Mornye pinned submodule, `third_party/audioplayers_android` | MIT | Android audio output and native equalizer bridge |
| Flutter / Dart SDK | Google | BSD-style | App framework and runtime |

Preserve the copyright and licence files in the upstream submodule when redistributing source or binaries. The relevant MIT licence texts are available at:

- `upstream/mornye/third_party/audio_service/LICENSE`
- `upstream/mornye/third_party/audioplayers_android/LICENSE`

The root `COPYING` file is the GPL-3.0 licence text distributed with the Mornye source tree. Its presence as a licence document does **not** mean Auralis has copied Mochy code or that Auralis is being relicensed as GPL. The Mornye source tree itself declares LGPL-3.0-only at its root. Auralis currently uses only the two MIT-licensed plugin directories listed above; it has not integrated Mornye's Rust extension runtime.

## Mochy Music

Mochy Music is GPL-3.0. No Mochy Kotlin implementation or provider module has been copied into this repository. Auralis's current iTunes preview adapter is an independent implementation and does not include Mochy code.

## Release obligations

- Keep this notice, root `LICENSE`, root `COPYING`, and the upstream submodule licence files with source releases.
- Generate and review a complete transitive dependency licence report before publishing a public APK.
- If Mornye Rust code or Mochy code is added later, re-audit the combined work and update the licence notices before distribution.
- Do not redistribute provider audio unless the provider explicitly authorizes the download.
