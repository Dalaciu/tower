# AltStore source for this fork

This fork publishes an unsigned IPA plus an AltStore source manifest so you can sideload
Tower on your iPhone with AltStore or SideStore. No Apple Developer Program needed.

## Source URL

Add to AltStore → Browse → Sources → `+`:

```
https://raw.githubusercontent.com/Dalaciu/tower/main/source.json
```

## How releases work

1. Push a tag matching `v*` on `main` (or run the `Release unsigned IPA` workflow by hand).
2. `.github/workflows/release-ipa.yml` builds an unsigned IPA on `macos-latest`, creates a
   GitHub release, attaches `Tower-unsigned.ipa`, and rewrites `source.json` so
   AltStore picks the new version up.
3. AltStore re-signs the IPA against your free Apple ID on install and re-sign events.

## One-time setup

- **Enable Actions on the fork.** GitHub disables workflows on forks by default.
  Open Actions tab → "I understand my workflows, go ahead and enable them."
- **Change `DEVELOPMENT_TEAM`** in `Tower.xcodeproj/project.pbxproj` to your own
  team ID before the first local Xcode build if you also want to build in Xcode. The
  release workflow builds with signing disabled, so the stock value does not block CI.
- **Change `PRODUCT_BUNDLE_IDENTIFIER`** if you have the upstream Tower from the App
  Store installed. Keeping the same bundle id as the store build makes AltStore replace it
  on install.
- **(Optional) Host via GitHub Pages** if you want a prettier URL. Settings → Pages →
  deploy from `main` branch, `/` directory. The raw URL above works without Pages.

## Xcode version caveat

The project targets iOS 26 and Swift 6, which need Xcode 27. `macos-latest` GitHub-hosted
runners may not yet ship Xcode 27. If the workflow fails at the build step, either:

- Wait for GitHub to add a `macos-26` runner image with Xcode 27, or
- Build the IPA locally with the script below and attach it to a release by hand.

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

Then: GitHub UI → Releases → Draft a new release → tag `v2.0.4-unsigned.1` → attach
`Tower-unsigned.ipa` → publish. `source.json` on `main` needs the `downloadURL`, `version`,
`size`, `versionDate` fields updated to match.

## PAT scopes for the workflow

`${{ github.token }}` has all it needs. No extra secrets.
