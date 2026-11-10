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

Auralis-owned source is currently released under LGPL-3.0-only (see the root LICENSE). The app uses the MIT-licensed audio_service and audioplayers_android packages located in the pinned Mornye submodule. The submodule's root LGPL/GPL licence documents are retained as upstream files; the presence of COPYING is not a relicensing of Auralis. No Mochy GPL-3.0 Kotlin source has been copied. See THIRD_PARTY_NOTICES.md. This remains a preliminary licence review: transitive pub dependencies and provider terms must be audited before public distribution. If GPL-3.0 Mochy code or additional Mornye Rust components are added, re-evaluate the combined work and its source-distribution obligations.
