# Changelog

## 02-04-2026
- Added OTML alias resolution so `.otui` files can declare variables (e.g. `&primaryColor`) and reference them as `$primaryColor`, improving theme consistency and readability.

## 05-12-2023
### Breaking API Changes
- `UIWidget` property `qr-code` & `qr-code-border` replaced with `UIQrCode` properties `code` & `code-border`
- `image-source-base64` replaced with `image-source: base64:/path/to/image`
- `#include "shadermanager.h"` moved to `#include <framework/graphics/shadermanager.h>`
