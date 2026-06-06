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

- archive-first installation from release/tag package
- manifest-driven installation
- packaged files list (including large binaries distributed as `.zip`/`.rar`)
- extraction of `.zip` and `.rar`
- optional `.lzma` decompression

## Integrity and Security Defaults

Defaults are hardened:

- `strictManifestSha256 = true`
- `allowRawFallbackHashMismatch = false`

Release cache is scoped per source (`releasesUrl` / repository key), avoiding stale cross-source reuse.

## Runtime/Platform Notes

- Desktop targets use `libarchive` for archive extraction.
- Android build excludes `libarchive` dependency (CI compatibility). In this target, archive extraction through `ResourceManager` is unavailable and returns failure explicitly.
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

### 2) SHA-256 mismatch

By default, mismatches fail installation. Verify upstream files and hashes first before changing integrity flags.

### 3) Slow progress / “stuck”

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

