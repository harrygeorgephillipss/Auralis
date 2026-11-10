# Security, privacy and licensing checklist

- Keep both original ZIP archives unchanged.
- Do not commit API keys, cookies, tokens, credentials, personal data or local build secrets.
- Do not bypass DRM, subscriptions, authentication, rate limits or provider access controls.
- Download only media the user is authorized to download from the relevant source.
- Show the source provider and actual format/quality for each download.
- Do not claim a lossy transcode is lossless.
- Review each provider's terms, copyright permissions and regional availability.
- Preserve upstream copyright and license notices for reused code and assets.
- Audit transitive dependencies and native binaries before each public release.
- Document telemetry and provide clear privacy controls.
- Treat extension packages as untrusted input; validate signatures, permissions and update sources.

## License posture

The current scaffold uses LGPL-3.0-only because Mornye is the planned Flutter/Rust base. This is provisional pending a full asset and dependency audit. If GPL-3.0 Mochy code is copied into the combined application, re-evaluate the distribution license and obligations before publishing.
