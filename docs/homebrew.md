# Homebrew Distribution Guide / Homebrew 分发指南

OverShelf is published through the `ALLENYGY/tap` Homebrew tap. This guide
covers installation and future release updates.

OverShelf 已通过 `ALLENYGY/tap` 发布。本指南说明安装方式与后续版本更新流程。

---

## 1. Install / 安装

```bash
brew tap ALLENYGY/tap
brew install --cask overshelf
```

## 2. Build a release artifact / 构建发布产物

```bash
./script/build_and_run.sh build
cd dist
xattr -cr OverShelf.app
COPYFILE_DISABLE=1 zip -qry -X OverShelf-1.1.2.zip OverShelf.app
shasum -a 256 OverShelf-1.1.2.zip   # copy this hash into the cask
```

## 3. Tag and publish a release / 打 tag 并发布 Release

```bash
git tag v1.1.2
git push origin v1.1.2
# Upload OverShelf-1.1.2.zip as a release asset on the GitHub release page,
# or use gh:
gh release create v1.1.2 dist/OverShelf-1.1.2.zip \
  --title "OverShelf 1.1.2" --generate-notes
```

The downloadable URL will look like:

```
https://github.com/ALLENYGY/overshelf/releases/download/v1.1.2/OverShelf-1.1.2.zip
```

## 4. Update the Homebrew tap / 更新 Homebrew tap

Update `Casks/overshelf.rb` in the existing `ALLENYGY/homebrew-tap` repository:

```ruby
cask "overshelf" do
  version "1.1.2"
  sha256 "fcb48b82edbd7eb2ba1c407141186e00563e00b059ec0d1c6eccaa62708ff655"

  url "https://github.com/ALLENYGY/overshelf/releases/download/v#{version}/OverShelf-#{version}.zip"
  name "OverShelf"
  desc "Dropdown drawer for clipboard history, file staging, notes, and todos"
  homepage "https://github.com/ALLENYGY/overshelf"

  depends_on macos: :sonoma

  app "OverShelf.app"

  zap trash: [
    "~/Library/Application Support/OverShelf",
    "~/Library/Preferences/com.overshelf.app.plist",
  ]
end
```

## 5. Upgrade and uninstall / 升级与卸载

```bash
brew upgrade --cask overshelf
brew uninstall --cask overshelf
brew uninstall --cask --zap overshelf
```

## 6. Updating a release / 更新版本

1. Bump `MARKETING_VERSION` / `CFBundleShortVersionString` in `project.yml`
   and `OverShelf/Info.plist`.
2. Rebuild and re-zip, recompute the SHA256.
3. Tag `v<new-version>` and publish the release with the new zip.
4. Edit `Casks/overshelf.rb` in the tap repo: bump `version` and `sha256`,
   then commit. `brew upgrade` picks it up automatically.

---

## Notes / 备注

- OverShelf is ad-hoc signed, so the cask does not perform notarization
  verification. If you notarize the app later, add `livecheck` and
  `pkg`/`appcast` stanzas as needed.
- For a private/organization tap, users do `brew tap <org>/<tap>` with the
  same pattern; the repo must be public for unauthenticated `brew install`.
- The `zap trash` block removes local data on `brew uninstall --cask
  --zap overshelf` so users can fully clean up.

English readme: [README.md](../README.md) | Chinese readme: [README.zh-CN.md](../README.zh-CN.md)
