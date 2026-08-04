# Homebrew Distribution Guide / Homebrew 分发指南

This guide explains how to publish OverShelf so users can install it with
`brew install --cask overshelf`.

本指南说明如何发布 OverShelf，让用户通过 `brew install --cask overshelf` 安装。

---

## 1. Create a GitHub repository / 创建 GitHub 仓库

```bash
cd /path/to/OverShelf
git init
git add .
git commit -m "Initial commit"
git branch -M main
git remote add origin https://github.com/ALLENYGY/overshelf.git
git push -u origin main
```

## 2. Build the release artifact / 构建发布产物

```bash
./script/build_and_run.sh build
cd dist
zip -r OverShelf-1.0.0.zip OverShelf.app
xattr -cr OverShelf.app   # keep the bundle clean before zipping
shasum -a 256 OverShelf-1.0.0.zip   # copy this hash into the formula
```

## 3. Tag and publish a release / 打 tag 并发布 Release

```bash
git tag v1.0.0
git push origin v1.0.0
# Upload OverShelf-1.0.0.zip as a release asset on the GitHub release page,
# or use gh:
gh release create v1.0.0 dist/OverShelf-1.0.0.zip \
  --title "OverShelf 1.0.0" --notes "First release"
```

The downloadable URL will look like:

```
https://github.com/ALLENYGY/overshelf/releases/download/v1.0.0/OverShelf-1.0.0.zip
```

## 4. Create a Homebrew tap / 创建 Homebrew tap

A tap is just another GitHub repo named `homebrew-<something>`. Homebrew finds
casks/formulae in any repo prefixed with `homebrew-`.

```bash
gh repo create ALLENYGY/homebrew-tap --public
```

Inside that tap repo, create `Casks/overshelf.rb`:

```ruby
cask "overshelf" do
  version "1.0.0"
  sha256 "ee37d6b6738941f9506dba34fac3fc01c8be6d24030e32ce8b9077c679b20f82"

  url "https://github.com/ALLENYGY/overshelf/releases/download/v#{version}/OverShelf-#{version}.zip"
  name "OverShelf"
  desc "macOS dropdown drawer for clipboard history, file staging, notes, and todos"
  homepage "https://github.com/ALLENYGY/overshelf"

  depends_on macos: ">= :sonoma"

  app "OverShelf.app"

  zap trash: [
    "~/Library/Application Support/OverShelf",
    "~/Library/Preferences/com.overshelf.app.plist",
  ]
end
```

## 5. Install / 安装

Users then run:

```bash
brew tap ALLENYGY/tap
brew install --cask overshelf

# later
brew upgrade --cask overshelf
```

Homebrew will download the zip, verify the SHA256, and move `OverShelf.app`
into `/Applications`.

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
