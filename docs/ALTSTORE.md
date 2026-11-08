# AltStore source for this fork

This fork publishes an unsigned IPA plus an AltStore source manifest so you can sideload
Tower on your iPhone with **AltStore Classic** or **SideStore**. No Apple Developer
Program needed.

## Which client

The source is for **AltStore Classic** (worldwide, free Apple ID, 7-day re-sign) or
**SideStore** (maintained AltStore-Classic fork, same source format). It is **not**
compatible with **AltStore PAL**, the EU DMA alternative marketplace: PAL only installs
Apple-notarized apps and requires every entry to carry a Apple-assigned `marketplaceID`.
If you see the error

> One or more apps in source "Dalaciu Tower" are missing a marketplaceID. This most likely
> means they are not notarized, which is not supported by this version of AltStore.

you are on AltStore PAL. Switch to AltStore Classic or SideStore:

- AltStore Classic: https://altstore.io/download — "AltStore Classic" button, not PAL.
- SideStore: https://sidestore.io.

## Source URL

Add to the client → Browse → Sources → `+`:

```
https://raw.githubusercontent.com/Dalaciu/tower/main/source.json
```

## How releases work

The repo uses [release-please](https://github.com/googleapis/release-please) and
[Conventional Commits](https://www.conventionalcommits.org/) to compute versions
automatically. No manual tagging.

1. Commits to `main` use conventional messages:
   - `feat: …` → minor bump (e.g. 2.0.4 → 2.1.0)
   - `fix: …` → patch bump (2.0.4 → 2.0.5)
   - `feat!: …` or footer `BREAKING CHANGE:` → major bump (2.0.4 → 3.0.0)
   - `chore: …` / `docs: …` / `ci: …` → no release
2. `release-please` opens or updates a "chore: release X.Y.Z" PR that bumps
   `.release-please-manifest.json`, `CHANGELOG.md`, and `source.json`'s
   `apps[0].version`.
3. Merging that PR creates tag `vX.Y.Z` and a GitHub Release.
4. The same `release.yml` workflow runs the `build-ipa` job on the `xcode-27` runner,
   builds an unsigned IPA, extracts metadata (version, bundle id, min OS, size, sha256,
   `appPermissions` from Info.plist + Mach-O entitlements), publishes SLSA build
   provenance via `actions/attest-build-provenance`, uploads the IPA and a zipped
   `.dSYM` to the release, and patches `source.json` with the new entry.
5. AltStore Classic / SideStore picks up the new `source.json` and re-signs the IPA
   against your free Apple ID at install time.

## One-time setup

- **Actions enabled.** Already on.
- **Change `DEVELOPMENT_TEAM`** in `Tower.xcodeproj/project.pbxproj` to your own team id
  only if you also want to build locally in Xcode. The release workflow builds with
  signing disabled, so the stock value is fine for CI.
- **Change `PRODUCT_BUNDLE_IDENTIFIER`** if you have the upstream Tower installed from
  the App Store and want them side by side. Same bundle id replaces the store build.

## Xcode version

`build-ipa` runs on the GitHub-hosted `xcode-27` runner image (iOS 27.1 SDK, Xcode 27),
which is what this project targets. If GitHub ever retires that image, update the
`runs-on` value in `.github/workflows/release.yml`.

## Rebuilding the IPA for an existing release

If a release's `build-ipa` run failed (e.g. a transient runner issue) and you need to
rebuild against the same tag without cutting a new version, trigger `Release` manually
with `rebuild_tag` set to the tag you want:

```sh
gh workflow run release.yml -f rebuild_tag=v2.1.0
```

The job re-runs the build step for that tag, re-uploads `Tower-unsigned.ipa` with
`--clobber`, and re-patches `source.json`.

## Local unsigned IPA build (fallback)

```sh
cd tower
xcodebuild \
  -project Tower.xcodeproj -scheme Tower \
  -configuration Release -sdk iphoneos \
  -destination 'generic/platform=iOS' \
  -derivedDataPath build \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY="" DEVELOPMENT_TEAM="" \
  clean build
mkdir -p Payload
cp -R build/Build/Products/Release-iphoneos/Tower.app Payload/
zip -qry Tower-unsigned.ipa Payload
```

## PAT scopes for the workflow

`${{ github.token }}` is enough for release-please and the IPA upload. No extra secrets
required.
