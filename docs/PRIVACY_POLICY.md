# Auralis privacy policy

Last updated: 10 November 2026

## Data stored on your device

Auralis stores your library metadata in a local SQLite database. Audio files you import are copied into Auralis's private app storage. The app does not currently provide cloud sync or an account system.

## Network requests

When you search in Explore, Auralis sends the search term to Apple's public iTunes Search API and receives catalogue metadata, artwork URLs, provider links, and preview URLs. Selecting a result streams the preview from the URL supplied by Apple. Apple's own privacy policy and service terms apply to those requests and streams.

## Data collection

The current Auralis app does not include an Auralis-operated analytics, advertising, or account backend. It does not intentionally transmit your local library database or imported audio files to Auralis servers.

## Permissions

- Internet: catalogue search and preview playback.
- Foreground media playback and wake lock: continued playback and system media controls.
- Android notification permission: playback notification behavior on Android versions that require it.
- File selection: user-selected audio is imported through Android's document picker; Auralis does not request broad storage access.

## Retention and deletion

Your imported files and library database remain in the app's private storage until you remove tracks or uninstall the app. Android automatic app-data backup is disabled in the current build; Auralis does not provide cloud sync. Uninstalling Auralis normally removes its private app data.

## Contact

This is a project-stage privacy notice. Before publishing Auralis to a public app store, add a maintained contact address and review the policy against the exact permissions, SDKs, and network behavior of the release build.
