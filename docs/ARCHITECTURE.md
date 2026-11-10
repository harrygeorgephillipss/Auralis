# Auralis architecture

## Guiding principle

Keep the user interface independent from providers and playback implementations. UI widgets should not scrape websites, download files, or own playback state directly.

## Layers

1. **Presentation** — Flutter screens, reusable components, themes and navigation.
2. **Application** — feature controllers/use-cases for search, queue, downloads, library and settings.
3. **Domain** — Track, Album, Artist, Provider, DownloadTask, AudioSource and PlaybackState models.
4. **Infrastructure** — provider adapters, audio engine, database, file storage, Android media session and optional Rust FFI.

## Proposed feature modules

- `features/home`
- `features/explore`
- `features/library`
- `features/player`
- `features/downloads`
- `features/providers`
- `features/settings`

## Provider contract

Every provider adapter should declare:
- provider ID and version
- supported operations (search, metadata, stream, download)
- supported formats and actual quality tiers
- authentication requirements
- regional / rate-limit constraints
- legal source and terms URL
- error and cancellation behavior

Provider adapters must not bypass paywalls, DRM, access controls or provider restrictions.

## Audio format handling

- Preserve the original source bytes when downloading.
- Report codec, bitrate, sample rate, bit depth and channel count only when measured or provided by trusted metadata.
- FLAC is lossless; AAC is lossy. A file extension alone is not proof of codec.
- Never transcode AAC/MP3 to FLAC and claim it is lossless.
- Keep playback, download and conversion pipelines distinct.
