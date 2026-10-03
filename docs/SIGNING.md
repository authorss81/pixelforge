# Signing PixelForge for release

## Why this exists

The debug key signs every developer build on every machine identically, which
sounds convenient until it matters. A debug-signed release **cannot be updated
in place** — Android refuses to install an update signed with a different key —
and the Play Store **rejects debug-signed uploads outright**. Shipping one by
accident is a one-way mistake: users would have to uninstall and reinstall.

So this project fails loudly. A release build without `android/key.properties`
does not fall back to the debug key. It throws, names the file, and points here.

## One-time setup

Generate a keystore. Guard it like a password, because it is one. Anyone holding
it can publish updates as you.

```bash
keytool -genkeypair -v -keystore ~/pixelforge-release.jks \
  -alias pixelforge -keyalg RSA -keysize 2048 -validity 10000
```

Copy the example and fill it in:

```bash
cp android/key.properties.example android/key.properties
```

```properties
storeFile=/absolute/path/to/pixelforge-release.jks
storePassword=<the store password you chose>
keyAlias=pixelforge
keyPassword=<the key password you chose>
```

`storeFile` may be absolute, which is recommended, or relative to `android/app/`.

Verify at any time:

```bash
cd android && ./gradlew :app:verifyReleaseSigning
```

## What happens without it

- `flutter run`, `flutter run --debug`, `flutter build apk --debug` — work
  exactly as before, signed with the debug key.
- `flutter build apk --release`, `flutter build appbundle --release`, and
  `flutter run --release` — fail with a `GradleException` naming
  `android/key.properties` and this document.

That asymmetry is deliberate. Debug builds are yours to break. A release build
is a promise to every future install, and it must be signed properly or not at
all.

## CI

CI has no keystore checked in — there must never be one. `build.yml` either
reconstructs the real key from the `RELEASE_KEYSTORE_B64` secret, or, when that
secret is absent, generates a throwaway key with `keytool` so the build and the
APK permission check still run. A throwaway-signed APK proves the pipeline, not
the product; it must never be published.

To add the real key:

```bash
base64 -w0 ~/pixelforge-release.jks
```

Store the output as the `RELEASE_KEYSTORE_B64` repository secret, plus
`KEYSTORE_PASSWORD`, `KEY_ALIAS` and `KEY_PASSWORD`. All four are environment
secrets, not repository secrets, so a compromised workflow run cannot read them
unless it is deploying.

```bash
gh secret set RELEASE_KEYSTORE_B64 --repo authorss81/pixelforge --env production < release.b64
gh secret set KEYSTORE_PASSWORD    --repo authorss81/pixelforge --env production
gh secret set KEY_ALIAS            --repo authorss81/pixelforge --env production
gh secret set KEY_PASSWORD         --repo authorss81/pixelforge --env production
```

## Losing the key

If the keystore is lost, there is no recovery. Google Play supports key upgrade
through Play App Signing only if it was enrolled **before** the loss. Keep an
offline backup in two places.
