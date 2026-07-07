# Contributing to Trans-Hub

## Git workflow (TH-002)

```
main       ← protected; production-ready, release-tagged
develop    ← integration branch for the next release
feature/*  ← new work, branched off develop
hotfix/*   ← urgent fixes, branched off main
release/*  ← release stabilization
```

### Rules

- `main` is **protected** — no direct pushes.
- All changes land via **pull request**.
- A PR requires:
  - ✅ Passing CI (`.github/workflows/flutter.yml`)
  - ✅ At least one code review
  - ✅ Up-to-date with the base branch

### Commit messages

Conventional Commits:

```
feat(scope): …      fix(scope): …       refactor(scope): …
test(scope): …      docs(scope): …      chore(scope): …
```

## Quality gates (TH-003 / TH-004)

> The CI workflow lives at [`ci/flutter.yml`](ci/flutter.yml). Copy it to
> `.github/workflows/flutter.yml` to activate it (it is kept under `ci/`
> because the automation token used to push this repo lacks the GitHub
> `workflows` permission).

Every push and PR runs:

```bash
flutter pub get
dart format --output=none --set-exit-if-changed .
flutter analyze        # strict lints (see analysis_options.yaml)
flutter test --coverage
flutter build web --release
```

Run them locally before opening a PR:

```bash
cd flutter_app
flutter pub get
dart format .
flutter analyze
flutter test
```

## Architecture

The app follows Clean Architecture (see `flutter_app/README.md`):

```
presentation → domain → data
```

- **UI/providers** talk only to **use cases** or **Riverpod providers**.
- **Repositories** are accessed through interfaces in `domain/repositories/`.
- Dependencies are resolved via the get_it container (`core/di/injection.dart`).
- One file per entity in `domain/entities/`; serialization lives in `data/models/`.
