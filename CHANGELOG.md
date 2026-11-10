# Changelog

## 0.4.0 — Android 9+ readiness and branding

- Set Android minimum SDK to API 28 and target SDK to API 36 in the reproducible Android build preparation step.
- Added a monochrome adaptive Auralis launcher icon and dark native launch background.
- Added a short animated A-mark Flutter launch screen.
- Configured music audio-session attributes and added a fallback to in-app playback if Android media-service initialization fails.
- Made SQLite open initialization safe against overlapping calls.
- Copy imported audio into app-private persistent storage instead of retaining temporary picker paths.
- Prevent overlapping catalogue searches from replacing newer results.
- Validate preview URLs as HTTPS before adding them to the library.
- Validate and clamp equalizer input values; playback continues if the native equalizer is unavailable.
- Added in-app About and open-source licence pages.
- Documented upstream MIT and LGPL/GPL licence boundaries.
