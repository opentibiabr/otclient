# Offline Assets Editor 15.x

The optional Assets Editor edits modern 15.x client assets while the client is offline. It is available in builds compiled with `TOGGLE_FRAMEWORK_EDITOR=ON`.

## Work copy

Opening the editor creates or resumes a working copy at `<client write directory>/sprite-editor/data/things/<version>/`. The editor mounts that copy for editing; the installed `data/things/<version>/` package stays unchanged until installation.

Use **Load assets** to select an installed version. If a working copy already exists, the editor asks before replacing it with a fresh copy of the installed assets. This discards the old working copy and its saved edits.

On a clean installation with no 15.x package, opening the editor offers the newest 15.x version supported by the build through the existing client-assets download flow. Confirming downloads the package to `data/things/<version>/` and opens its working copy. If the download is canceled, the version selector remains available and **Download and load** can retry or download another supported version. The selector only lists versions supported by `modules/gamelib/game.lua`.

## Edit appearances and sprites

Choose a category and appearance from the left panel. The center preview shows the selected sprite or animation frame. The Properties page edits the available flags, values, and animation settings for that appearance.

For item appearances, **Values** exposes typed scalar values, enum selections, optional values, and repeated enum choices used by fields such as Market profession restrictions. Clearing an optional value removes it from the working copy. Market and Cyclopedia metadata stay in the appearance flags data; they are not written to legacy `.dat`/`.spr` files.

Use **Copy** to create a new ID from the selected appearance, or **New** (Import > **Create**) to make one in the chosen category from a sprite ID or PNG. **Delete** removes only the selected appearance record from the working copy and keeps all sprite data. Reloading the installed assets discards these edits.

On the Import page, replace the selected frame with another sprite ID by selecting or dragging a sprite from the right panel onto the preview. To import artwork, choose a PNG file and import it; the editor creates a sprite ID and links it to the selected frame. The file browser opens in `data/things/pngs/` by default, and also supports navigating to another folder. PNGs placed in `data/things/pngs/` are ignored by Git.

The **Batch PNGs** option imports a folder of up to 256 individual prepared PNGs, subject to the 64 MiB decoded-image limit. **Sheet** splits a regular grid: choose the cell dimensions, select an inclusive row-major cell range (cell 1 is the top-left; last cell `0` means the rest of the sheet), and optionally skip fully transparent cells. One sheet import can inspect at most 64 cells. Imported PNGs receive new sprite IDs; they do not create appearances by themselves.

To edit a sprite in another application, choose **Edit sprite**. The editor exports a temporary PNG to the user's client profile and launches the configured external editor as a separate desktop window. Save the image in that application, return to OTClient, and apply the edit. The image must keep the sprite's original dimensions. Every appearance that shares this sprite ID uses the updated image.

The **Appearance** export creates a portable bundle for the selected appearance. It can also export the appearances currently visible in the left list after filtering, up to 8 at a time. Existing bundle folders are not overwritten. On import, choose one bundle folder or a parent folder containing bundles; up to 64 bundles are processed independently. A failed bundle does not undo earlier successful bundles, so the status reports partial results. The work copy remains separate from installed assets until installation.

## Install edited assets

The Export page installs the working copy into the standard runtime location, `data/things/<version>/`. After confirmation, the current package is moved to `data/things/backup/<version>-<timestamp>/`, the working copy replaces it, and the client reloads appearances and static data. The backup directory is ignored by Git.

When the editor closes, it unmounts the working copy and restores the installed package as the runtime source. The editor only supports directory-based client assets in the 15.x range; it does not modify older `.dat`/`.spr` clients.

## Edit history and recovery

Undo and Redo revert edits in the active working copy. The editor also records portable edit metadata and before/after sprite images in `asset-editor-history.json` inside that package. The History page lists recorded edits. The **Backups** tab on the Export page lists installed backups newest first and shows their recorded changes when available. Restoring a selected backup does not create another backup.

## Manual validation for contributors

The editor is built behind the CMake option `TOGGLE_FRAMEWORK_EDITOR=ON`. Build and launch the client using the normal instructions for the target platform, then open the editor while offline. Use a dedicated client write directory and a disposable work directory with a separate `data/things` tree; do not use a production package for destructive checks. The version selector only offers 15.x versions listed in `modules/gamelib/game.lua` (`g_game.getSupportedClients()`).

Run these checks on each desktop platform being validated:

1. With no installed 15.x package in a disposable work directory, open the editor. Confirm the missing-assets prompt offers the newest supported version, download it, and verify the working copy opens. Repeat and cancel the prompt; confirm the version selector and **Download and load** action let you retry or choose another supported version.
2. Open a working copy, switch among Objects, Outfits, Effects, and Missiles, and confirm the selection, preview, and applicable property controls follow the selected appearance.
3. In Import, replace a frame with an existing sprite ID, then import a same-size PNG as a new sprite and link it to that frame. Confirm the new sprite appears in the preview and in the working copy after reload.
4. Edit a sprite through the configured external editor, save it without changing its dimensions, apply it, and verify the preview and edit-history entry. Exercise Undo and Redo.
5. Duplicate an appearance, change its properties and flags, and verify that the source appearance remains unchanged. For an animated appearance, play the preview, edit frame timing, add a frame, and remove one only after confirming the prompt.
6. Export to an unused supported version, load that version in the editor, and confirm its contents. Restore a selected installed backup and confirm the editor reports the package it restored. Keep these checks on the disposable assets copy.
7. Try a version not listed by `game.lua` (for example `15.99`) and confirm that the new-version export remains disabled and direct export is rejected.

On Windows, Linux, and macOS, also check that the PNG browser can navigate to a folder whose path contains spaces and non-ASCII characters, and that the configured editor opens in a separate OS window. Verify the path and launch feedback on that platform. The file browser and external-editor actions are desktop-only; Android and Web builds are not targets for those workflows. On those builds, check that the client still builds and does not expose an enabled desktop-only action.

For a useful report, include the OS and architecture, build configuration (including `TOGGLE_FRAMEWORK_EDITOR`), source asset version, numbered steps, expected and observed result, and the relevant client log or screenshot. Keep the working copy and backup disposable so another contributor can repeat the test safely.
