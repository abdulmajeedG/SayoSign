# SayoSign — “Ink & Ribbon” redesign

A presentation-only redesign of the SayoSign iOS app. The signing engine, Apple ID
authentication, hooking engine, Rust idevice bridge, installer and all business logic
are untouched.

## Design language

- **Ink & Ribbon** — deep aubergine ink in dark mode, warm porcelain in light mode,
  with a coral-to-rose ribbon accent.
- **Liquid Glass-inspired surfaces** on iOS 26+, with material fallbacks for iOS 15–25.
- **Rounded, layered cards** (24 pt radii), soft ambient shadows, hairline borders.
- **SF Rounded** for titles and numbers, SF Pro for body copy; Dynamic Type throughout.
- **Restrained motion** — spring presses, shared-element tab segments, a launch
  sequence that fades away after the app is already running.
- **RTL-first Arabic** with Unicode isolation for file extensions and protocol names.
- **12 languages**: English, Arabic, French, Portuguese, Simplified Chinese,
  Traditional Chinese, Spanish, German, Russian, Japanese, Turkish, Italian.

## Screens

The redesign covers the dashboard, imported/signed library, certificate cards,
certificate import, Apple ID sign-in and account management, sources and repository
details, texturing/tweak options, the signing flow with step progress, installer
setup, pairing, Anisette settings, storage, install log, language picker, appearance
selector, About/Credits, empty states, loading banners, error cards and toasts.

## Accessibility

- VoiceOver labels for icon-only controls.
- Logical RTL traversal and mirrored chevrons.
- Dynamic Type-friendly semantic type, with minimum-scale handling on dense labels.
- Reduced Motion respected by the launch animation.
- High-contrast, soft light/dark palettes; no pure white/black canvas.

## Credits

Designed with love by [@abdulmajeedG](https://t.me/abdulmajeedG) on Telegram.

SayoSign remains the original project by murk, licensed under GPL-3.0.

## Screenshots (iPhone 17, iOS 27.2)

| | |
|---|---|
| ![App icon](screenshots/00-app-icon.jpg) | ![Launch](screenshots/01-launch.jpg) |
| ![Library light](screenshots/02-library-light-en.jpg) | ![Library Arabic](screenshots/23-library-arabic.jpg) |
| ![Signing](screenshots/04-signing.jpg) | ![Signing options](screenshots/05-signing-options.jpg) |
| ![Certificates](screenshots/06-certificates.jpg) | ![Certificates Arabic](screenshots/07-certificates-arabic.jpg) |
| ![Apple ID](screenshots/08-apple-id.jpg) | ![Sources](screenshots/09-sources.jpg) |
| ![Settings](screenshots/11-settings.jpg) | ![Dark settings](screenshots/12-settings-dark.jpg) |
| ![Language picker](screenshots/14-language-picker.jpg) | ![Arabic settings](screenshots/15-settings-arabic.jpg) |
| ![About](screenshots/16-about.jpg) | ![Credits](screenshots/17-credits.jpg) |
| ![Pairing](screenshots/18-pairing.jpg) | ![Installer setup](screenshots/19-installer-setup.jpg) |
| ![Installer steps](screenshots/20-installer-steps.jpg) | ![French persistence](screenshots/22-french-persistence.jpg) |

Additional captures: `03-library-with-app-en.jpg`, `10-add-source.jpg`,
`13-settings-dark-scrolled.jpg`, `21-settings-french.jpg`.
