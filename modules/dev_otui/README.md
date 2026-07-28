# dev_otui — visual `.otui` editor

A development tool for building and editing `.otui` screens while seeing the
real result. The preview is drawn by OTClient's own renderer, so bitmap fonts,
`image-border` 9-slice and the whole style cascade are exact rather than an
approximation.

Open it with the button on the top-right menu, or `Ctrl+Alt+U`.

## Quick start

1. **Open...** and pick any `.otui` in the project — it renders on screen and
   the widget tree is filled in.
2. Click a widget in the tree, or tick **Edit** and click it directly on screen.
3. The property panel shows that widget's properties **as written in the file**.
   Change a value and press Enter (or **Apply (preview)**) to see it live.
4. **Save to file** writes the change back, keeping the rest of the file intact.

Tick **Auto-reload** to have the preview follow the file while you edit it in
your text editor.

## What each control does

| Control | Purpose |
| --- | --- |
| `Load` / `Open...` | load the `.otui` typed in the field, or pick one from a searchable list |
| `New screen` | create a new file with a minimal `MainWindow`; refuses to overwrite |
| `Reload` | re-read the file, keeping the current selection |
| `+ Element` | insert a child widget, picked from a palette that shows a live preview of each style |
| `- Element` | delete the selected widget from the file, children included (asks first) |
| `Anchor...` | pick an anchor for the selected widget from the valid combinations |
| `Guides` | draw the parent's area and centre lines, and box the widgets this one is anchored to |
| `Style gallery` | render every style of every file under `/styles` in one scrollable list, grouped by file |
| `Auto-reload` | watch the file and reload it on change (300 ms) |
| `Debug boxes` | toggle `g_ui.setDebugBoxesDrawing`, outlining every widget |
| `Edit` | click to select on screen, drag to move, green corner to resize |
| `$on` / `$checked` / `$disabled` | force widget states to inspect their styling |
| `Apply (preview)` | apply the panel to the live widget; the file is untouched |
| `Save to file` | write the changes to the `.otui` |

The gallery doubles as an audit of `data/styles`: a style that cannot be sampled
is listed with the reason instead of being hidden, and the same list is printed
to the terminal. The reason is worked out *before* instantiating — an unregistered
base class, a style nested inside another style, an `image-source` that is not in
the data folder — so the audit does not itself fill the log with engine errors.

Three classes are never instantiated at all (`UIStatsBar`, `UIPopupMenu`,
`UIPopupScrollMenu`). They build their own children in `create()` and expect a
host that a sample row cannot provide; standing alone, their layout never
settles and keeps rescheduling itself. Since deferred events are processed
inside the same dispatcher poll, that freezes the client with no error logged —
so they are refused up front rather than tried. The list is also built one
sample per frame: the window is drawn and usable while it fills, instead of the
client going dark through a single 250-sample layout pass.

## How it works

**The property panel mirrors the file's lines, not the widget's getters.**
`otml.lua` parses the `.otui` keeping the original lines, and edits rewrite only
the lines that change. Two consequences:

- Properties with no getter on `UIWidget` — `anchors.*`, `@onClick`, `!text` —
  are visible and editable, and values appear exactly as written.
- Saving preserves comments, blank lines, ordering and alignment.

**Dragging rewrites margins, not coordinates.** Which margin depends on the
anchors the widget declares in the file: with `anchors.left` a drag becomes
`margin-left`; with `anchors.right` it becomes `margin-right` inverted; with
both, the widget shifts while keeping its width.

**The element palette previews what you are adding.** Highlighting an entry in
`+ Element` instantiates that style live in the side panel, with its name, size
and the file and line where it is defined. Styles that cannot be built
standalone say so instead of showing an empty box.

**New widgets come in anchored.** A widget with no anchor cannot be positioned
or dragged at all, so inserting one writes anchors with it: hooked below the
previous sibling when there is one (`anchors.top: prev.bottom`), or to the
parent's top-left when it is the first child. If the parent has a `layout:`, the
parent places its children and anchors would be ignored, so none are written.

**`Anchor...` only offers legal combinations.** An edge can only hook to an edge
of the same axis — `anchors.top` accepts `top`, `bottom` and `verticalCenter`,
never `left`. The list is built from that rule, over the parent, `prev`, `next`
and every sibling that has an id, plus the `fill` and `centerIn` shortcuts.

**Guides show what the widget is anchored to.** Blue is the parent's *padding*
rect — the area children are actually laid inside — with its centre lines.
Orange boxes the sibling an anchor points at, so `prev.bottom` stops being
guesswork. They redraw on selection, not on every drag frame: the parent does
not move while you drag.

**Style-only files get a showcase.** A third of the project's `.otui` files
(every one under `/styles`) declares only styles and has no main widget, so
`loadUI` returns `nil` for them. For those the editor instantiates a live sample
of each style; selecting a sample edits the style definition in the file.

Styles that need a specific parent — `MiniWindow` expects a
`MiniWindowContainer` — cannot be instantiated standalone and are listed in red
instead of breaking the showcase.

## Safety

Writing is the only destructive operation, so it is guarded:

- a `.bak` copy is written before each save;
- after writing, the file is read back and compared before reporting success;
- selection is validated by walking the on-screen tree and the file tree in
  parallel, comparing the style name at every level. If they disagree — a widget
  that came from an inherited style, for instance — saving is refused rather
  than writing to the wrong node.

## Tests

The parser is the part capable of corrupting files, so it has a self test.
In the client terminal (`Ctrl+T`):

```lua
modules.dev_otui.selfTest()
```

It asserts, among others: byte-for-byte round-trip, composite blocks such as
`layout:` not being mistaken for child widgets, edits not touching neighbouring
lines, insertion indentation, and removal of a block taking its children along.

## Notes

- Editing a file under `/styles` changes a style used by the whole client, not
  by a single screen.
- `.otui` files are read with a CP1252 bitmap font; multi-byte UTF-8 characters
  render as garbage.
- Changing `dev_otui.otmod` requires restarting the client:
  `Module::reload()` reuses the script list captured at discovery time.
  Changes to `.lua` and `.otui` only need
  `g_modules.getModule('dev_otui'):reload()`.
