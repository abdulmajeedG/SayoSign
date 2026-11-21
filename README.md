<p align="center">
  <img src="docs/assets/icon.png" width="128" alt="SayoSign icon">
</p>

<h1 align="center">SayoSign</h1>

<p align="center">
  <b>A cute and very capable IPA signer that runs right on your iPhone.</b><br>
  Sign with a .p12 or a free Apple ID, inject tweaks with a home-made hooking engine, install offline.
</p>

<p align="center">
  <a href="https://github.com/murk-sus/SayoSign/actions"><img src="https://github.com/murk-sus/SayoSign/actions/workflows/build.yml/badge.svg" alt="Build"></a>
  <img src="https://img.shields.io/badge/iOS-15%2B-ff7e8a" alt="iOS 15+">
  <img src="https://img.shields.io/badge/license-GPL--3.0-f0566e" alt="GPL-3.0">
  <a href="README_RU.md"><img src="https://img.shields.io/badge/README-на%20русском-ffb3a7" alt="Russian"></a>
</p>

---

## ✨ Features

- **On-device signing.** Its own signing engine is written from scratch in C: Mach-O (thin and fat), SHA-256 CodeDirectory, CMS signature, XML and DER entitlements, nested frameworks and extensions, `_CodeSignature/CodeResources`, and ZIP64 IPA packing. It has no OpenSSL and no zsign inside.
- **Certificates.** Import a `.p12` with its `.mobileprovision`, see the team, expiry, devices and entitlements, and check **revocation live with OCSP** against Apple.
- **Apple ID sign-in.** Use a free or paid developer account directly. SayoSign speaks GrandSlam (SRP-6a with 2FA by trusted device or SMS) and Apple Developer Services to register your device, create a certificate and fetch a profile for every app on the fly.
- **Tweak injection.** Accepts `.dylib`, `.deb` (gzip, xz, lzma or zstd, with its own zstd decoder) and `.framework`. Substrate, ElleKit, libhooker and substitute dependencies are rewired automatically.
- **SayoHook,** a home-made hooking framework, is shipped as `CydiaSubstrate.framework` and exports `MSHookMessageEx`, `MSHookFunction`, `MSFindSymbol`, `MSGetImageByName`, `LHHookFunctions`, `LBHookMessage` and `substitute_*`.
  - Objective-C hooks work everywhere.
  - C function hooks work on stock iOS by rebinding symbol pointers, and use real ARM64 inline trampolines with instruction relocation when JIT is available.
- **Offline installs.** A tiny HTTPS server on `localhost` and `itms-services` install the app. Trust comes from a certificate authority generated on your device; its private key never leaves the phone, so there are no leaked keys and no third-party servers.
- **Sources.** AltStore, SideStore, Feather and ESign repositories with search, screenshots and one-tap download.
- **App tweaks.** Change the name, bundle ID, version, icon and minimum iOS. You can also remove extensions, Watch apps or URL schemes, enable Files sharing, and add extra entitlements.
- **Interface.** Pink-coral design with a little bow 🎀, Liquid Glass on iOS 26+, English and Russian.

## 📲 Install

1. Download `SayoSign.ipa` from [Releases](https://github.com/murk-sus/SayoSign/releases) (or the latest CI build in [Actions](https://github.com/murk-sus/SayoSign/actions)).
2. Sign it once with whatever you have: another signer, Sideloadly, AltStore, or the `sayosign` CLI from this repo (see below).
3. Open SayoSign → **Settings → Local installer setup** and follow the three steps. You only do this once.

## 🛠 Command-line signer

The same engine builds as a desktop CLI (Linux or macOS, needs OpenSSL for p12 parsing):

```sh
make
./build/sayosign sign -k cert.p12 -p 1234 -m profile.mobileprovision -i app.ipa -o signed.ipa \
    -n "My App" -l tweak.deb -H build/CydiaSubstrate.framework
./build/sayosign ocsp -k cert.p12 -p 1234
```

## 🧱 Building

The repository is built entirely by GitHub Actions; no Mac is needed.

- `make && ./tests/run.sh` builds the core and runs its tests (zstd, ZIP64, .deb, SRP-6a, AES-GCM and PBKDF2 checked against reference implementations).
- `xcodegen generate` then `xcodebuild …` builds the unsigned IPA (see `.github/workflows/build.yml`).

```
core/   C signing engine: Mach-O, CMS, ZIP, deb, zstd, X.509, OCSP, SRP, AES
hook/   SayoHook, the hooking framework shipped as CydiaSubstrate.framework
app/    SwiftUI app
cli/    desktop CLI around the core
docs/   website and AltStore source (GitHub Pages)
```

## 🧾 AltStore source

Add `https://murk-sus.github.io/SayoSign/source.json` to AltStore, SideStore, Feather or SayoSign itself.

## ⚖️ Legal

SayoSign signs apps with **your own** certificates for **your own** devices. Do not use it to distribute pirated software. Not affiliated with Apple.

The name is a nod to Sayori. No artwork from *Doki Doki Literature Club* is used. The icon is made with [Twemoji](https://github.com/jdecked/twemoji) 🎀 ✒️ (CC-BY 4.0).

Licensed under **GPL-3.0**.
