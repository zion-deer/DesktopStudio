# Contributing

Desktop Studio is a native macOS app. Changes should keep the theme model as the source of layout data and leave the real desktop unchanged until a desktop integration is intentionally added.

## Setup

- macOS 14 or later
- Xcode 15 or later, with the macOS 14 SDK

Open `DesktopStudio.xcodeproj` and run the Desktop Studio scheme.

```bash
xcodebuild -project DesktopStudio.xcodeproj -scheme DesktopStudio -destination 'platform=macOS' -configuration Debug build
xcodebuild -project DesktopStudio.xcodeproj -scheme DesktopStudio -destination 'platform=macOS' test
```

If signing has no development team, pass `CODE_SIGNING_ALLOWED=NO` for a local build, or `CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO` when a test host must launch.

## Versioning

The current version is **0.1.0**, build **1**. Theme documents are schema **2**. Schema 1 files still open through migration. Do not bump the schema without a migration and tests.

- `MARKETING_VERSION` in `DesktopStudio.xcodeproj` is the semantic version (`MAJOR.MINOR.PATCH`).
- `CURRENT_PROJECT_VERSION` is the monotonically increasing build number.
- `AppVersion.establishedMarketingVersion` and `AppVersion.establishedBuildNumber` must match those settings.
- Record user-visible changes in `CHANGELOG.md` under `[Unreleased]`.
- When cutting a version, move those notes under a dated heading and bump `MARKETING_VERSION`. Bump `CURRENT_PROJECT_VERSION` for every shippable build.

Do not tag or publish a release from an ordinary commit. A version tag such as `v0.2.0` must match `MARKETING_VERSION`, and `CURRENT_PROJECT_VERSION` must be greater than every build already published. `docs/UPDATES.md` lists the Apple and Sparkle secrets. Do not commit them.

## What not to commit

The repository ignores Xcode user data, build products, signing certificates, private keys, provisioning profiles, and local secret files. Do not add credentials, API tokens, or `DEVELOPMENT_TEAM` secrets to the project or to GitHub Actions.

## Tests

Add tests for layout math and theme serialization next to the change. UI-only preview code can stay untested. Do not claim a desktop overlay, custom Dock, or launcher works unless that behavior is implemented and tested.
