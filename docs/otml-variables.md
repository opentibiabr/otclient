# OTML Variable System

## Overview

The OTML parser supports a variable system using the `&` prefix for definitions and the `$` prefix for references. This document explains the behavior, scope rules, and important considerations.

## Syntax

### Variable Definition
```otui
&variableName: value
```

### Variable Reference
```otui
property: $variableName
```

## Scope Behavior

### Root-Level Variables (Global Scope)

Variables defined at the document root level are registered as **global OTML variables**:

```otui
&primaryColor: #FF0000
&spacing: 10

WindowStyle < UIWindow
  background-color: $primaryColor
  padding: $spacing
```

**Behavior:**
- Registered in the document's global alias map
- Accessible throughout the entire document and all nested nodes
- Warnings are issued if a global variable is redefined

### Nested Variables (Local Scope)

Variables defined within widget/style definitions have **local scope**:

```otui
MiniWindow < UIMiniWindow
  &minimizedHeight: 20
  
  UIWidget
    height: $minimizedHeight  // ✓ Resolves to "20"
```

**Behavior:**
- Only registered in the local alias map for that scope
- Accessible by all descendant nodes
- NOT registered as global OTML variables
- NOT accessible outside the defining node's hierarchy

## Important: Dual-Purpose `&` Prefix

### ⚠️ Semantic Ambiguity

The `&` prefix has a **dual purpose** in OTUI files, which creates potential for confusion:

#### 1. OTML Variable Definition
```otui
&myVariable: 100
```
Used with `$myVariable` to reference the value in descendant nodes.

#### 2. Lua Field Value Assignment
```otui
MiniWindow
  &minimizedHeight: 20   // Also a Lua field accessible from scripts
  &save: true            // Also a Lua field accessible from scripts
  &onClick: handler      // Lua callback function name
```

The UI system processes `&` nodes as Lua fields (see `UIWidget::parseBaseStyle` in `uiwidgetbasestyle.cpp`):
- Fields are set on the widget's Lua table
- Accessible from Lua scripts via `widget.fieldName`
- Used for custom widget properties and callbacks

### Consequences of Dual Purpose

#### Local Scope Pollution
Even though nested `&` nodes aren't global, they are added to the local alias map. This means:

```otui
MiniWindow < UIMiniWindow
  &minimizedHeight: 20      // Intended as Lua field
  &save: true               // Intended as Lua field
  
  UIWidget
    height: $minimizedHeight  // ✓ This works! Resolves to "20"
    width: $save              // ✓ This works! Resolves to "true"
```

While this doesn't break functionality, it creates ambiguity:
- Lua field values can unintentionally be used as OTML variables
- No clear distinction between "intended for Lua" vs "intended for OTML"
- Potential naming conflicts if not careful

## Variable Resolution

### Reference Syntax
Use `$` prefix to reference a variable:
```otui
width: $myVariable
color: $primaryColor
```

### Chained References
Variables can reference other variables:
```otui
&primaryColor: #FF0000
&accentColor: $primaryColor    // Resolves to #FF0000
&highlightColor: $accentColor  // Resolves to #FF0000
```

### Resolution Order
1. Check local scope (nearest parent `&` definitions)
2. Check parent scopes (walking up the hierarchy)
3. Check global scope (root-level `&` definitions)
4. Error if not found

### Circular Reference Detection
The parser detects and reports circular references:
```otui
&varA: $varB
&varB: $varA    // ✗ Error: Circular OTML variable reference
```

## Best Practices

### 1. Use Clear Naming Conventions

**For OTML variables (intended for `$` references):**
```otui
&PANEL_WIDTH: 200
&COLOR_PRIMARY: #FF0000
```
Use UPPER_SNAKE_CASE to clearly indicate these are variables.

**For Lua fields:**
```otui
&minimizedHeight: 20
&save: true
&onClick: handler
```
Use camelCase or lowercase to indicate these are Lua properties.

### 2. Document Intent
Add comments to clarify purpose:
```otui
// OTML Variables (for styling)
&BUTTON_HEIGHT: 32
&SPACING_LARGE: 20

// Lua Fields (for behavior)
MiniWindow
  &save: true
  &minimizedHeight: $BUTTON_HEIGHT
```

### 3. Avoid Name Collisions
Be cautious when naming Lua fields to avoid unintended variable resolution:
```otui
WindowStyle < UIWindow
  &padding: 10        // Lua field, but also resolvable as $padding
  
  UIWidget
    margin: $padding  // ⚠️ Unintentionally uses the Lua field value
```

### 4. Root-Level for Shared Constants
Define shared styling constants at the document root:
```otui
&COLOR_BACKGROUND: #1a1a1a
&COLOR_TEXT: #ffffff
&STANDARD_PADDING: 5

// All styles can use these
```

### 5. Local for Scope-Specific Values
Use local variables for values specific to a widget hierarchy:
```otui
ComplexPanel < UIWidget
  &HEADER_HEIGHT: 30
  &FOOTER_HEIGHT: 20
  
  Header
    height: $HEADER_HEIGHT
  Footer
    height: $FOOTER_HEIGHT
```

## Common Patterns

### Theme Colors
```otui
&COLOR_PRIMARY: #2196F3
&COLOR_SECONDARY: #FFC107
&COLOR_SUCCESS: #4CAF50
&COLOR_ERROR: #F44336

Button
  background-color: $COLOR_PRIMARY
  
ErrorLabel
  color: $COLOR_ERROR
```

### Consistent Sizing
```otui
&BUTTON_HEIGHT: 32
&ICON_SIZE: 16
&PADDING_STANDARD: 8

SmallButton < Button
  height: $BUTTON_HEIGHT
  padding: $PADDING_STANDARD
```

### Derived Values
```otui
&BASE_PADDING: 8
&DOUBLE_PADDING: 16     // Could also be calculated if expression support existed

Panel
  padding: $BASE_PADDING
  margin: $DOUBLE_PADDING
```

## Error Messages

The parser provides helpful error messages:

- **Undefined variable:** `"Undefined OTML variable: variableName"`
- **Circular reference:** `"Circular OTML variable reference: variableName"`
- **Malformed variable:** `"Malformed OTML variable: &"`
- **Global override:** `"Overriding global OTML variable: variableName"` (warning)

## Implementation Details

For developers working on the codebase:

- **Parser:** `src/framework/otml/otmlparser.cpp`
- **Variable resolution:** `resolveVariablesRecursive()` function
- **Global storage:** `OTMLDocument::m_globalAliases`
- **Local resolution:** Uses temporary `AliasMap` during parsing
- **Lua field processing:** `UIWidget::parseBaseStyle()` in `uiwidgetbasestyle.cpp`

### Processing Order
1. Parse OTML document structure
2. Call `resolveVariablesRecursive()` on document root
3. Process `&` nodes at each level:
   - Extract variable name (strip `&` prefix)
   - Resolve any `$` references in the value
   - Register in local alias map (all levels)
   - Register in global alias map (root level only)
4. Resolve `$` references in all other node values
5. UI system later processes `&` nodes as Lua fields

## Future Considerations

Potential improvements to address the dual-purpose ambiguity:

1. **Separate syntax:** Use different prefixes for variables vs Lua fields
   - Example: `$var:` for variable definitions, `&` for Lua fields
   
2. **Explicit variable declarations:** Add a dedicated variable section
   - Example: `variables:` block at document start
   
3. **Namespaces:** Allow prefixing to distinguish usage contexts
   - Example: `&lua.save` vs `&var.PRIMARY_COLOR`

Currently, the system works reliably but requires awareness of the dual-purpose nature of the `&` prefix.

## Examples

### Complete Working Example
```otui
// Global theme variables
&THEME_DARK_BG: #1e1e1e
&THEME_TEXT: #ffffff
&BUTTON_HEIGHT: 32

// Style with Lua fields and local variables
MainWindow < UIWindow
  background-color: $THEME_DARK_BG
  &save: true         // Lua field for persistence
  
  // Local variable for this hierarchy
  &CONTENT_PADDING: 10
  
  ContentPanel < UIWidget
    padding: $CONTENT_PADDING
    
    Button
      height: $BUTTON_HEIGHT
      color: $THEME_TEXT
      &onClick: onButtonClick   // Lua callback
```

This document should help developers understand the variable system and avoid common pitfalls while working with OTUI files.
