# Client Assets Auto-Install

This document describes the automatic client assets installation flow introduced in OTClient.

## Goal

For modern Tibia client versions (>= 1281), OTClient must be able to:

1. Detect missing assets for the selected version.
2. Prompt the user to download required assets.
3. Download and install assets automatically.
4. Keep final installed files in the same paths already used by OTC runtime.

## Final Install Paths (Source of Truth)

Installed assets must end up in:

- `data/things/<version>/`
- `data/sounds/<version>/`
- runtime extras (when provided by upstream package), such as `bin/*`, in client runtime paths.

Do not introduce an alternative permanent assets root for runtime loading.

## Main Module

- Lua module: `modules/client_assets/client_assets.lua`
- Enter-game integration: `modules/client_entergame/entergame.lua`
- Modern things/sounds loading: `modules/game_things/things.lua`

## Download / Install Strategy

The flow supports:

- archive installation from the release/tag source ZIP as the default path
- manifest-driven installation as a fallback path when the archive cannot be installed
- manifest hash identifier installation into `data/things/<version>/assets.json.sha256`
- packaged files list (including large binaries distributed as `.zip`/`.rar`)
- extraction of `.zip` and `.rar`
- optional `.lzma` decompression

## Integrity and Security Defaults

Defaults are hardened:

- `strictManifestSha256 = true`
- `allowRawFallbackHashMismatch = false`
- `allowMissingPackedRawFallback = true`

`allowMissingPackedRawFallback` is a narrow compatibility fallback for repository releases that reference official `.lzma`/archive package files not stored in the assets repository. It is only used after the packed file is missing and the client falls back to the raw file from the same manifest/release source. It does not enable arbitrary hash mismatches for normal raw downloads.

Release cache is scoped per source (`releasesUrl` / repository key), avoiding stale cross-source reuse.

## Runtime/Platform Notes

- Desktop targets use `libarchive` for archive extraction when it is available.
- Builds without `libarchive` still extract `.zip` archives through the vendored minizip fallback. This keeps the GitHub source ZIP flow functional on clean desktop builds.
- `.rar` extraction requires `libarchive`. If a packaged `.rar` is optional and the build cannot extract it, installation should fail clearly or skip it according to the package configuration.
- The default flow is archive-first because the release source ZIP is the canonical package for this repository. The manifest path remains a compatibility fallback, not the primary installation path.
- Emscripten login fallback was aligned with native `httpLogin` semantics.

## UX Behavior

- Missing-assets dialog prompts before download.
- Download window supports cancellation.
- Progress supports indeterminate mode when remote does not provide reliable content length.
- Console logs show major phases and final install paths.

## Troubleshooting

### 1) Assets appear downloaded but game still cannot load

Check:

- `data/things/<version>/catalog-content.json`
- `data/things/<version>/assets.json.sha256`
- `data/sounds/<version>/catalog-sound.json` (when sounds are enabled)

### 2) Missing `.lzma` package file

If the console shows a 404 for `*.lzma`, the client is using the manifest fallback instead of the release source ZIP. First check why archive installation failed. The manifest fallback can install raw files through `allowMissingPackedRawFallback`, but this path is slower and should not be the normal flow for clean installs.

### 3) SHA-256 mismatch

By default, mismatches fail installation. Verify upstream files and hashes first before changing integrity flags.

### 4) Slow progress / “stuck”

If Content-Length is missing, UI may run in indeterminate mode during download and extraction. Use console logs to confirm active phase.

## Configuration (init.lua)

`Services.clientAssets` supports runtime behavior controls (repository, archive preference, sounds, packaged files, hash strictness, etc.). Keep secure defaults unless there is a specific compatibility reason to relax.

## Maintenance Checklist

When changing this system, validate:

1. Missing assets prompt appears for modern version.
2. Install completes into `data/things/<version>` and `data/sounds/<version>`.
3. Runtime loads modern assets from those paths.
4. Hash verification behavior matches configuration.
5. Windows/Linux CI remains green; Android does not attempt to resolve unsupported libarchive linkage.
