# Updates

Desktop Studio uses [Sparkle 2.10.0](https://sparkle-project.org/documentation/) to check for and install updates. Published archives and the Sparkle appcast live on GitHub. A push to `main` builds and tests the app. It does not publish a release.

The bundle identifier is `com.desktopstudio.app`. The deployment target is macOS 14. The marketing version and build number in the Xcode project are the only version source of truth.

## What an installed copy does

A published build has two Info.plist values:

- `SUFeedURL`, the stable appcast address
- `SUPublicEDKey`, the Ed25519 public key from Sparkle’s `generate_keys`

Sparkle checks that feed about once a day (`SUScheduledCheckInterval` is 86400). `SUEnableAutomaticChecks` is true, so the app does not ask again on the second launch. `SUAutomaticallyUpdate` is false, so Sparkle asks before it installs. The standard Sparkle window shows download progress, success, and failure.

Desktop Studio → Check for Updates… and Settings → Updates run the same check. Settings also turns automatic checks on or off by setting `automaticallyChecksForUpdates`. That value is Sparkle’s own preference.

The app is sandboxed, so it follows Sparkle’s sandbox guide:

- `SUEnableInstallerLauncherService` is true
- the app has the outgoing network client entitlement
- the entitlements allow the mach names `com.desktopstudio.app-spks` and `com.desktopstudio.app-spki`

The Downloader XPC service is not enabled, because the app already has the network client entitlement. `SUVerifyUpdateBeforeExtraction` is true, so Sparkle checks the EdDSA signature before it unpacks an archive.

A local build leaves the feed URL and public key empty. The updater stays off and Settings explains that. Themes are not touched.

Sparkle replaces the `.app` bundle. Themes stay in `~/Library/Application Support/Desktop Studio/Themes/`. The desktop session stays in `~/Library/Application Support/Desktop Studio/Runtime/`. An offline Mac, a missing feed, a bad signature, or a release that requires a newer macOS leaves the installed copy in place. Sparkle’s window explains the failure, and Settings repeats that nothing was replaced.

## What you configure once

Create the GitHub repository and push this project there. Enable Actions. Create an environment named `release` and, if you want a person to approve publication, add required reviewers to that environment.

Generate the Sparkle key on your Mac with the `generate_keys` tool from the [Sparkle 2.10.0 distribution](https://github.com/sparkle-project/Sparkle/releases/download/2.10.0/Sparkle-2.10.0.tar.xz). Run it once:

```bash
./bin/generate_keys -x "$HOME/DesktopStudio-sparkle-private-key"
```

The tool prints the public key and writes the private key to that file. Put the public key in a GitHub Actions **variable** named `DESKTOP_STUDIO_SPARKLE_PUBLIC_KEY`. Put the private key file contents in a GitHub Actions **secret** named `SPARKLE_EDDSA_PRIVATE_KEY`. Do not commit the private key. Do not put it in the app.

Enable GitHub Pages for the `gh-pages` branch. The first successful release creates that branch. The feed URL you put in the variable `DESKTOP_STUDIO_UPDATE_FEED_URL` must be the Pages URL that ends with `appcast.xml`, for this repository’s owner and name. It is not a `/releases/latest` link.

Create an Apple Developer ID Application certificate and a Developer ID provisioning profile for `com.desktopstudio.app`. The profile must include the sandbox, user-selected files, outgoing network, and the two Sparkle mach-lookup exceptions. Export the certificate as a `.p12`.

Create an App Store Connect API key that can submit software for notarization. Download the `.p8` once.

### GitHub secrets

| Secret | Value |
| --- | --- |
| `BUILD_CERTIFICATE_BASE64` | `base64` of the Developer ID `.p12` |
| `P12_PASSWORD` | Password for that `.p12` |
| `APPLE_TEAM_ID` | Apple Team ID |
| `DEVELOPER_ID_PROFILE_BASE64` | `base64` of the Developer ID `.provisionprofile` |
| `APP_STORE_CONNECT_API_KEY_ID` | App Store Connect key ID |
| `APP_STORE_CONNECT_API_ISSUER_ID` | App Store Connect issuer ID |
| `APP_STORE_CONNECT_API_KEY` | Contents of the `.p8` file |
| `SPARKLE_EDDSA_PRIVATE_KEY` | Contents of the Sparkle private key file |

### GitHub variables

| Variable | Value |
| --- | --- |
| `DESKTOP_STUDIO_UPDATE_FEED_URL` | Stable `https` appcast URL ending in `appcast.xml` |
| `DESKTOP_STUDIO_SPARKLE_PUBLIC_KEY` | Public key printed by `generate_keys` |

The release workflow stops if any of these are missing, if tests fail, if signing or notarization fails, or if the tag does not match `MARKETING_VERSION`.

## Publishing a release

1. Develop and commit on `main`.
2. Push. The CI workflow builds and tests. It does not create a release.
3. Set `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` in the Xcode project, and set the same strings in `AppVersion.swift`. The build number must be greater than every build already published.
4. Record the change in `CHANGELOG.md`.
5. Push `main`, wait for CI, then tag the commit that is on `main`:

```bash
git tag v0.2.0
git push origin v0.2.0
```

The tag must be `v` plus `MARKETING_VERSION`. You can instead run the Release workflow manually and type that existing tag. The workflow rejects a tag that is not contained in `main`, a version that does not match the project, a build number that does not increase, and a release that already exists.

The workflow archives the Desktop Studio scheme in Release, exports a Developer ID app, notarizes it, staples the ticket, zips only the app, and signs that zip with Sparkle’s `sign_update` from the pinned 2.10.0 archive. It uploads `DesktopStudio-<version>.zip` to that tag’s GitHub Release and adds an appcast item whose enclosure URL is:

`https://github.com/<owner>/<repo>/releases/download/v<version>/DesktopStudio-<version>.zip`

## Testing an update

1. Publish one signed release and install the zip from its GitHub Release. Copy it to `/Applications`. Open Settings → Updates and confirm the feed is configured.
2. Bump the marketing version and build number, push, and publish a second tag.
3. In the installed older copy, choose Desktop Studio → Check for Updates… Sparkle should offer the new build. Install it. Confirm the version changed and that themes in Application Support are still there.
4. Turn off the network and check again. The installed app should remain, with a message that the feed could not be reached.
5. Point a test feed at an archive signed with a different key. Sparkle should reject it and leave the app installed. Do not ship that feed.
6. Confirm a normal push to `main` does not create a GitHub Release.

Delta updates are not generated. Each release is a full zip, which Sparkle can still install.
