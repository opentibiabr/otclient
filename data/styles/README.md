# OTML Variables for OTClient Styles

OTML files can now expose lightweight variables that keep palettes, spacing tokens and theme tweaks in sync without rewriting the same literals across styles. In this context, a standalone OTML node whose tag begins with `&` is treated as a variable definition and is skipped by `UIManager` when instantiating widgets; its value is made available to subsequent nodes through `$name` references.

> **Note on existing `&` syntax:** Older `.otui` files already use `&` as a prefix for Lua-backed widget fields (for example `&minimizedHeight`, `&static`). That syntax remains valid: lines like `&minimizedHeight: 42` inside a widget definition still define Lua fields on the widget. With the current resolver, nested `&` nodes can also participate as local OTML aliases, while root-level aliases are additionally exported globally. This overloading of `&` is intentional and backward-compatible.
## How it works

* Declare a variable by prefixing a node tag with `&` and assigning a literal value, for example `&primaryColor: #33AAFF`.
* Use that variable later in the file by writing `$primaryColor` in fields that expect literals (colors, borders, paddings, etc.). The parser resolves these references before Lua expression evaluation occurs.
* Variables inherit down the tree. A definition near the root of a `.otui` is also saved into `OTMLDocument::globalAliases`, which allows other files loaded afterward to reuse the same tokens.
* A variable can reference another variable (`&accentColor: $primaryColor`). Cycles and undefined references are reported in the console so you can catch mistakes early.
* Outer quotes are stripped during resolution; the unquoted literal is substituted directly, which keeps the value from being re-evaluated as a Lua expression.

## Example file

`data/styles/global_alias_test.otui` is not tied to a real in-game window—it exists solely to demonstrate and exercise the alias resolution path. If the resolver were broken, this file would trigger an error in `otclient.log` when `UIManager` loads it, so it acts as a lightweight sanity check.

```otui
&primaryColor: #33AAFF
&secondaryColor: $primaryColor
&lightText: '#FFFFFF'

TestGlobalStyle < UIWidget
  color: $lightText
  background-color: $secondaryColor
  border-color: $primaryColor

DerivedPanel < UIWidget
  &panelAccent: $secondaryColor
  color: $primaryColor
  background-color: $lightText
  text-color: $secondaryColor
  padding: $panelAccent
  PanelHeader < UIWidget
    &headerAccent: $panelAccent
    background-color: $headerAccent
    padding: $headerAccent
```

The alias nodes never create widgets; they only populate the resolver so the colors above resolve to the expected literals.
Within `DerivedPanel` we define `&panelAccent` (a node-scoped alias) before any style fields to show aliases can live inside a node and feed sibling properties like `padding`. `PanelHeader` takes the same alias and redefines it locally via `&headerAccent` to demonstrate nested alias chains without introducing actual windows.

## Best practices

* Keep palette and spacing variables in dedicated `.otui` files and import them from your screens to ensure consistency.
* Avoid overlapping names across scopes when you intend to share tokens globally—reusing the same name in the document root makes the value available to every style file that loads afterward.
* Since `UIWidget::parseBaseStyle` evaluates expressions in Lua, rely on the resolver to deliver already-evaluated literal tokens for properties that only support strings, colors or file paths.
