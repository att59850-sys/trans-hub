# Deployment Guide (TH-025)

Trans-Hub ships from a single Flutter codebase to **Web**, **Android**, and
**iOS**. Continuous Deployment is defined in `ci/deploy.yml`.

> **Activating the workflows.** The automation token used in this repo lacks the
> GitHub `workflows` scope, so the pipelines live under `ci/`. To enable them,
> a maintainer copies them into `.github/workflows/`:
>
> ```bash
> mkdir -p .github/workflows
> cp ci/flutter.yml  .github/workflows/flutter.yml   # CI  (TH-004)
> cp ci/deploy.yml   .github/workflows/deploy.yml     # CD  (TH-025)
> git add .github/workflows && git commit -m "ci: enable workflows" && git push
> ```

## Triggers

| Event | Result |
|-------|--------|
| Push a tag `vX.Y.Z` | Production release of web + Android + iOS |
| Manual *Run workflow* | Pick a single target (`web` / `android` / `ios` / `all`) |

```bash
# cut a release
git tag v1.0.0 && git push origin v1.0.0
```

## Required GitHub secrets

Configure under **Settings → Secrets and variables → Actions**.

### Backend (all targets, injected via `--dart-define`)
| Secret | Purpose |
|--------|---------|
| `SUPABASE_URL` | Supabase project REST URL |
| `SUPABASE_ANON_KEY` | Supabase anon/public key |
| `ADMIN_EMAILS` | comma-separated emails granted the in-app verification review queue (TH-017) |

### Web — Cloudflare Pages
| Secret | Purpose |
|--------|---------|
| `CLOUDFLARE_API_TOKEN` | Pages-scoped API token |
| `CLOUDFLARE_ACCOUNT_ID` | Cloudflare account id |
| `CF_PAGES_PROJECT` | Pages project name |

### Android — Google Play (Fastlane `supply`)
| Secret | Purpose |
|--------|---------|
| `ANDROID_KEYSTORE_BASE64` | base64 of the upload keystore (`.jks`) |
| `ANDROID_KEYSTORE_PASSWORD` / `ANDROID_KEY_ALIAS` / `ANDROID_KEY_PASSWORD` | signing config |
| `PLAY_SERVICE_ACCOUNT_JSON` | Play service-account JSON (Release Manager) |

### iOS — App Store Connect (Fastlane)
| Secret | Purpose |
|--------|---------|
| `APP_STORE_CONNECT_KEY_ID` / `APP_STORE_CONNECT_ISSUER_ID` | API key identity |
| `APP_STORE_CONNECT_KEY_BASE64` | base64 of the `.p8` key |
| `MATCH_PASSWORD` | passphrase for the `match` certificates repo |

If a target's secrets are absent the job still **builds** and uploads the
artifact, but skips the store upload — so PRs and forks stay green.

## Fastlane

Per-platform lanes live next to the native projects:

```
flutter_app/android/fastlane/Fastfile   # lanes: build, deploy (internal), promote
flutter_app/ios/fastlane/Fastfile       # lanes: build, beta (TestFlight), release
```

Run locally (after `flutter build`):

```bash
cd flutter_app/android && bundle install && bundle exec fastlane deploy
cd flutter_app/ios     && bundle install && bundle exec fastlane beta
```

## Manual builds

```bash
cd flutter_app
flutter build web       --release --dart-define=APP_ENV=production
flutter build appbundle --release --dart-define=APP_ENV=production
flutter build ipa       --release --dart-define=APP_ENV=production
```
