# Installing Auralis

## Supported Android versions

- Minimum: Android 9 (API 28).
- Target: Android 16 (API 36).
- Architectures: Flutter's Android release defaults. The APK workflow currently builds a universal APK.

## Install from an APK

1. Download the release APK from the repository's GitHub Actions artifact or a tagged release.
2. On the Android device, allow installation from the browser or file manager used to open the APK.
3. Open the APK and install it.
4. Open Auralis and grant any Android notification permission requested by the operating system.

## First use

- Use **Import music** to select local audio. Auralis copies selected files into its private app storage so the library does not depend on temporary picker cache files.
- Use **Explore** for catalogue discovery. The current iTunes adapter returns short preview streams, not full tracks.
- The five-band equalizer depends on Android's DynamicsProcessing support (Android 9+); unsupported devices can still play audio.
- Open **Settings → Open-source licences** to view the Auralis LGPL text and third-party notices.
- Background media controls are provided through Android's media session.

## Known feature boundary

The full Mornye Rust extension runtime, extension marketplace, and provider-authorized download queue are not yet integrated. The Downloads tab is intentionally marked unavailable rather than presenting a non-functional control as complete.
