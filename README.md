
<h1>
  <img src="https://github.com/mehah/otclient/blob/main/data/images/clienticon.png?raw=true" width="32" alt="logo"/>
  OTClient - Redemption
</h1>

[![Discord Shield](https://discordapp.com/api/guilds/888062548082061433/widget.png?style=shield)](https://discord.gg/tUjTBZzMCy)
[![Build - Ubuntu](https://github.com/mehah/otclient/actions/workflows/build-ubuntu.yml/badge.svg)](https://github.com/mehah/otclient/actions/workflows/build-ubuntu.yml)
[![Build - Windows](https://github.com/mehah/otclient/actions/workflows/build-windows.yml/badge.svg)](https://github.com/mehah/otclient/actions/workflows/build-windows.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

---

## <a id="table-of-contents"></a>📋 Table of Contents
1. ![Logo](https://raw.githubusercontent.com/mehah/otclient/main/src/otcicon.ico)  [What is OTClient?](#what-is-otclient)
2. 🚀 [Features](#features)
3. <img height="16" src="https://raw.githubusercontent.com/github/explore/80688e429a7d4ef2fca1e82350fe8e3517d3494d/topics/android/android.png"/> [The Mobile Project](#the-mobile-project)
4. 🔨 [Compiling](#compiling)
5. 🐳 [Docker](#docker)
6. 🩺 [Need Help?](#need-help)
7. 📑 [Bugs](#bugs)
8. ❤️ [Roadmap](#roadmap)
9. 💯 [Support Protocol](#support-protocol)
10. ©️ [License](#license)
11. ❤️ [Contributors](#contributors)

---

## <a id="what-is-otclient"></a>![Logo](https://raw.githubusercontent.com/mehah/otclient/main/src/otcicon.ico) What is OTClient?
OTClient is an alternative Tibia client for usage with OTServ. It aims to be **complete** and **flexible**:

- **LUA scripting** for all game interface functionality
- **CSS-like syntax** for UI design
- **Modular system**: each functionality is a separate module, allowing easy customization
- Users can create new mods and extend the interface
- Written in **C++20** and heavily scripted in **LUA**

For a server to connect to, you can build your own with **theforgottenserver** or **canary**.

> [!NOTE]
> Based on [edubart/otclient](https://github.com/edubart/otclient) • Rev: [2.760](https://github.com/edubart/otclient/commit/fc39ee4adba8e780a2820bfda66fc942d74cedf4)

---

## <a id="features"></a>🚀 Features

Beyond its flexibility with scripts, OTClient comes with many features that enable client-side innovation in OTServ: **sound system**, **graphics effects with shaders**, **modules/addons**, **animated textures**, **styleable UI**, **transparency**, **multi-language**, **in-game LUA terminal**, and an **OpenGL 2.0 ES engine** that allows porting to mobile platforms. It is also flexible enough to create Tibia tools like map editors using scripts—OTClient is a **framework + Tibia APIs**.

### ⚡ Performance & Engine
<details>
  <summary>🖼️ Draw Render (optimization showcase)</summary>

  https://github.com/user-attachments/assets/fe5f1d7f-7195-4d65-bca6-c2b5d62d3890
</details>

<details>
  <summary>📦 Asynchronous Texture Loading</summary>

- **Description**: with this the spr file is not cached, consequently, less RAM is consumed.
- **Video**:

  https://github.com/kokekanon/otclient.readme/assets/114332266/f3b7916a-d6ed-46f5-b516-30421de4616d
</details>

<details>
  <summary>🧵 Multi-threading</summary>

**Main Thread**
- Sound
- Particles
- Load Textures (files)
- Windows Events (keyboard, mouse, ...)
- Draw texture

**Thread 2**
- Connection
- Events (g_dispatcher)
- Collect information on what will be drawn on the Map

**Thread 3**
- Collect information on what will be drawn in the UI

**Image:**  
![multinucleo](https://github.com/kokekanon/otclient.readme/assets/114332266/95fb15ac-553f-4eca-937d-8c8f49990f3e)
</details>

<details>
  <summary>🧹 Garbage Collection</summary>

**Description (1):**
```
Garbage Collection is the feature responsible for automatically managing memory by identifying and releasing objects that are no longer in use. This allows the client to maintain efficient memory usage, avoid unnecessary data accumulation, and improve overall stability.
```

**Description (2):**  
Garbage collector is used to check what is no longer being used and remove it from memory. *(lua, texture, drawpool, thingtype)*
</details>

<details>
  <summary>🧭 Texture Atlas System</summary>

*(coming with engine improvements and draw-call reduction)*
</details>

- C++20 ( v17 , Unity build and Manifest Mode *(vcpkg.json)* ) build in x32 and x64  
- Walking System Improvements  
- Supports sequenced packages and compression  
- Asserts load (Tibia 13)

---

### 🎛️ UI & UX
<details>
  <summary>🧩 UIWidgets Improvements</summary>

- **Description:** Improvements in the UI algorithm; better performance in add/remove/reposition widgets. Visible in the **battle module**.
- **Video:**  

  https://github.com/user-attachments/assets/35c79819-b78b-4578-a4a2-af1235139807
</details>

<details>
  <summary>🔁 Auto Reload Module</summary>

Activate: `g_modules.enableAutoReload()` ([init.lua](https://github.com/mehah/otclient/blob/main/init.lua#L114))  
Video:  

https://github.com/kokekanon/otclient.readme/assets/114332266/0c382d93-6217-4efa-8f22-b51844801df4
</details>

<details>
  <summary>✨ Attached Effects System (aura, wings…)</summary>

- Compatible with **.APNG**
  - ThingCategoryEffect
  - ThingCategoryCreature
  - ThingExternalTexture: images in **PNG | APNG**
- **Wiki:** https://github.com/mehah/otclient/wiki/Tutorial-Attached-Effects
- **Example Code:** [effects.lua](https://github.com/mehah/otclient/blob/main/modules/game_attachedeffects/effects.lua) • [test code](https://github.com/mehah/otclient/blob/main/modules/game_attachedeffects/attachedeffects.lua#L1)  
- **Specific lookType settings:** [outfit_618.lua](https://github.com/mehah/otclient/blob/main/modules/game_attachedeffects/configs/outfit_618.lua)

> [!TIP]
> You can adjust offsets per looktype using **ThingConfig** when a default offset doesn’t align perfectly for a given sprite.

<p align="center">
<table>
<tr>
<td><img src="https://github.com/kokekanon/OTredemption-Picture-NODELETE/blob/main/Picture/Attached%20Effect/Creature/001_Bone.gif?raw=true" width="200"></td>
<td><img src="https://github.com/kokekanon/OTredemption-Picture-NODELETE/blob/main/Picture/Attached%20Effect/Creature/002_aura.gif?raw=true" width="200"></td>
<td><img src="https://github.com/kokekanon/OTredemption-Picture-NODELETE/blob/main/Picture/Attached%20Effect/Creature/003_particula.gif?raw=true" width="250"></td>
</tr>
<tr>
<td align="center">ThingCategory Attached Effect</td>
<td align="center">Texture (PNG) Attached Effect</td>
<td align="center">Particule</td>
</tr>
</table>
</p>
</details>
<details>
  <summary>🧭 Module Controller System</summary>

A safer way to create modules, without the need to unbind keys, disconnect events, or destroy widgets.  
**Example:** ([modules/game_minimap/minimap.lua](https://github.com/mehah/otclient/blob/cache-for-all/modules/game_minimap/minimap.lua))
</details>

<details>
  <summary>🖼️ Anti-Aliasing Mode Options</summary>

- *Note*: **Smooth Retro** will consume a little more GPU.

**GIF:**  
![aa](https://github.com/kokekanon/otclient.readme/assets/114332266/5a411525-7d5a-4b16-8bb6-2c6462152d39)
</details>

<details>
  <summary>🧩 Creature Information by UIWidget</summary>

- Enable: [setup.otml](https://github.com/mehah/otclient/blob/e2c5199e52bd86f573c9bb582d7548cfe7a8b026/data/setup.otml#L20)
- Style: [modules/game_creatureinformation](https://github.com/mehah/otclient/tree/main/modules/game_creatureinformation)
- **Note:** There is a performance degradation vs direct Draw Pool, about ~20%, tested with 60 monsters attacking each other.

**Video:**  

https://github.com/kokekanon/otclient.readme/assets/114332266/c2567f3f-136e-4e11-964f-3ade89c0056b
</details>

<details>
  <summary>🧱 Tile Widget</summary>

Wiki: https://github.com/mehah/otclient/wiki/Tutorial-Attached-Effects

<p align="center">
<table>
<tr>
<td><img src="https://github.com/kokekanon/OTredemption-Picture-NODELETE/blob/main/Picture/Attached%20Effect/Tile/001_attachedeffect.gif?raw=true" width="250"></td>
<td><img src="https://github.com/kokekanon/OTredemption-Picture-NODELETE/blob/main/Picture/Attached%20Effect/Tile/002_widget.png?raw=true" width="200"></td>
<td><img src="https://github.com/kokekanon/OTredemption-Picture-NODELETE/raw/main/Picture/Attached%20Effect/Tile/003_particulas.gif?raw=true" width="310"></td>
</tr>
<tr>
<td align="center">Title Attached Effect</td>
<td align="center">Title Widget</td>
<td align="center">Title Particule</td>
</tr>
</table>
</p>
</details>

<details>
  <summary>🧩 Support HTML/CSS Syntax</summary>

https://github.com/user-attachments/assets/b16359d3-09a4-4181-bcb8-c76339b64b37

https://github.com/user-attachments/assets/d3844223-7e35-45da-a872-3141f1c5860a

https://github.com/user-attachments/assets/9f20814f-0aed-4b70-8852-334ac745ec11  

https://github.com/user-attachments/assets/3ac8473c-8e90-4639-b815-ef183c7e2adf

**Module examples:**  
- [Shader](https://github.com/mehah/otclient/tree/main/modules/game_shaders)  
- [Blessing](https://github.com/mehah/otclient/pull/825)
</details>

<details>
  <summary>🎥 Latency-adaptive camera</summary>

Basically the camera adapts to the server latency to always remain smooth and avoid stuttering while walking.  
If the ping gets high, the camera moves slower to keep up with the server's response time; if the ping drops, the camera moves faster. *(Depends on character speed.)*
</details>

<details>
  <summary>🧭 Support Negative Offset (.dat)</summary>

- Compatible with [ObjectBuilderV0.5.5](https://github.com/punkice3407/ObjectBuilder/releases/tag/v0.5.5)  
- Enable: `g_game.enableFeature(GameNegativeOffset)`

**Video:**  

https://github.com/kokekanon/otclient.readme/assets/114332266/16aaa78b-fc55-4c6e-ae63-7c4063c5b032
</details>

- Floor Shadowing  
- Highlight Mouse Target *(press **Shift** to select any object)*  
- Floor View Mode *(Normal, Fade, Locked, Always, Always with transparency)*  
- Floating Effects Option  
- Refactored Walk System  
- Support for more mouse buttons *(e.g., 4 and 5)*
- Support DirectX  
- Hud Scale

---

### 🔗 Compatibility & Protocols
- Client **7.6 ~ 12.85 ~ 12.92**, **13.00 ~ 15.11** support *(protobuf)*  
- Market rewritten (compatible with TFS and Canary)  
- Async Texture Loading *(engine-level feature)*  
- Supports sequenced packages and compression  

> [!NOTE]
> See section **[💯 Support Protocol](#support-protocol)** for a full compatibility matrix and required flags.

---

### 🧩 Community Mods & Integrations

#### 🙋 Community (Features)

<details>
  <summary>🕹️ Discord RPC — @SkullzOTS</summary>

- by [@SkullzOTS](https://github.com/SkullzOTS), [@surfaceflinger](https://github.com/surfaceflinger) and [@libergod](https://github.com/libergod)
- To enable just go to [config.h](https://github.com/mehah/otclient/blob/main/src/framework/config.h#L43), set **1** in `ENABLE_DISCORD_RPC` and configure the others definitions
- If using CMake execute: 
  - Removes Content of Build Folder if needed
  - `if (Test-Path -Path build) { Remove-Item -Path build -Recurse -Force; New-Item -Path build -ItemType Directory }` 
  - Configure CMake
  - `cmake -B build -G "Ninja" -DENABLE_DISCORD_RPC=ON`
  - Build it
  - `cmake --build build`
- Step-by-step on **YouTube**: https://www.youtube.com/watch?v=zCHYtRlD58g

<p align="center">
<table>
<tr>
<td><img src="https://github.com/kokekanon/OTredemption-Picture-NODELETE/blob/main/Picture/Discord/001.png?raw=true" width="200"></td>
<td><img src="https://github.com/kokekanon/OTredemption-Picture-NODELETE/blob/main/Picture/Discord/002_ingame.png?raw=true" width="200"></td>
<td><img src="https://github.com/kokekanon/OTredemption-Picture-NODELETE/blob/main/Picture/Discord/003_future.png?raw=true" width="200"></td>
</tr>
<tr>
<td align="center">Example interface</td>
<td align="center">Example in game</td>
<td align="center">future discord-game-sdk</td>
</tr>
</table>
</p>
</details>
<details>
  <summary>🔐 Encryption System — @Mrpox *(unsafe implementation)*</summary>

- by [@Mrpox](https://github.com/Mrpox)  
- Enable via [config.h](https://github.com/mehah/otclient/blob/main/src/framework/config.h#L33): set **ENABLE_ENCRYPTION=1** and change **ENCRYPTION_PASSWORD**  
- To enable building encryption with `--encrypt`, set **ENABLE_ENCRYPTION_BUILDER=1** (by [@TheMaoci](https://github.com/TheMaoci)) — removes encryption code from production build
- Generate encrypted files by running client with: `--encrypt SET_YOUR_PASSWORD_HERE` (or omit to use the password from [config.h](https://github.com/mehah/otclient/blob/main/src/framework/config.h#L38))

> [!WARNING]
> This encryption implementation is considered **unsafe**. Use at your own risk.
</details>
<details>
  <summary>⬆️ Client Updater — @conde2</summary>

- by [@conde2](https://github.com/conde2)  
- Paste the **API** folder in your www folder: https://github.com/mehah/otclient/tree/main/tools/api  
- Create a folder called `files` in your www and paste `init.lua`, `modules`, `data`, and `exe`  
- Uncomment and change this line: https://github.com/mehah/otclient/blob/main/init.lua#L6
</details>

<details>
  <summary>🌈 Colored Text — @conde2</summary>

- by [@conde2](https://github.com/conde2)  
- Usage: `widget:setColoredText("{Colored text, #ff00ff} normal text")`
</details>

<details>
  <summary>🔳 QR Code support — @conde2</summary>

- by [@conde2](https://github.com/conde2)  
- **UIQrCode** properties example:
  - `code-border: 2`
  - `code: Hail OTClient Redemption - Conde2 Dev`
</details>

<details>
  <summary>💬 Typing Icon — @SkullzOTS</summary>

- by [@SkullzOTS](https://github.com/SkullzOTS)  
- Enable in [setup.otml](https://github.com/mehah/otclient/blob/main/data/setup.otml): set `draw-typing: true`

<p align="center">
  <img src="https://github.com/kokekanon/OTredemption-Picture-NODELETE/blob/main/Picture/typing%20ico/001.gif?raw=true" width="200">
</p>
</details>

<details>
  <summary>🪜 Smooth Walk Elevation — @SkullzOTS</summary>

- by [@SkullzOTS](https://github.com/SkullzOTS)  
- Preview: [Gyazo](https://i.gyazo.com/af0ed0f15a9e4d67bd4d0b2847bd6be7.gif)  
- Enable in [modules/game_features/features.lua](https://github.com/mehah/otclient/blob/main/modules/game_features/features.lua#L5): uncomment line 5 (`g_game.enableFeature(GameSmoothWalkElevation)`)

<p align="center">
  <img src="https://github.com/kokekanon/OTredemption-Picture-NODELETE/blob/main/Picture/smooth/001_smooth.gif?raw=true" width="200">
</p>
</details>

<details>
  <summary>🗺️ Layout based on Tibia 13 — @marcosvf132</summary>

- by [@marcosvf132](https://github.com/marcosvf132)  
- **Game_shop** based on Store by [@Oskar1121](https://github.com/Oskar1121/Store), modified/fixed by [@Nottinghster](https://github.com/Nottinghster/)
- **Minimap WorldTime**
  - TFS C++ (old): `void ProtocolGame::sendWorldTime()`
  - TFS LUA (new): `function Player.sendWorldTime(self, time)`
  - Canary: `void ProtocolGame::sendTibiaTime(int32_t time)`
- **Outfit windows** compatible with attachEffect, shader  
  - Canary  
  - **1.4.2**: https://github.com/kokekanon/TFS-1.4.2-Compatible-Aura-Effect-Wings-Shader-MEHAH/commit/77f80d505b01747a7c519e224d11c124de157a8f  
  - **Downgrade**:  
    - https://github.com/kokekanon/forgottenserver-downgrade/pull/2  
    - https://github.com/kokekanon/forgottenserver-downgrade/pull/7  
    - https://github.com/kokekanon/forgottenserver-downgrade/pull/9
- Calendar
- `client_bottommenu` (activate `Services.status` array in `init.lua`)

**Status service**  
Put `./otclient/tools/api/status.php` in:  
`C:/UniServerZ/www/api/`

If it doesn't work, enable **curl**:

![image](https://github.com/Nottinghster/otclient/assets/114332266/99ad2ce7-d70f-47f4-aa19-083140fb5814)
![image](https://github.com/Nottinghster/otclient/assets/114332266/84349388-a458-4eb5-b1d6-cce5693cfd5a)

<p align="center">
<table>
<tr>
<td><img src="https://github.com/kokekanon/OTredemption-Picture-NODELETE/blob/main/Picture/Layout%2013/001_interface.png?raw=true" width="300"></td>
<td><img src="https://github.com/kokekanon/OTredemption-Picture-NODELETE/blob/main/Picture/Layout%2013/002_ingame.png?raw=true" width="300"></td>
</tr>
<tr>
<td align="center">Interface</td>
<td align="center">In-game</td>
</tr>
</table>
</p>

- Imbuement tracker — by [@Reyaleman](https://github.com/reyaleman)  
- Blessing  
- Screenshot  
- Highscores  
- Store *(compatible with 1098, 12.91 ~ 13.40)*  
- QuickLoot  
- Groups Vip  
- Reward Wall *(Daily Rewards)*
</details>

<details>
  <summary>🌐 Browser Client — @OTArchive</summary>

- by [@OTArchive](https://github.com/OTArchive)  
- Wiki: https://github.com/OTArchive/otclient-web/wiki/Guia-%E2%80%90-OTClient-Redemption-Web  
- Video: https://github.com/user-attachments/assets/e8ab58c7-1be3-4c76-bc6d-bd831e846826
</details>

- Mobile Support — by [@tuliomagalhaes](https://github.com/tuliomagalhaes) • [@BenDol](https://github.com/BenDol) • [@SkullzOTS](https://github.com/SkullzOTS)

<p align="center">
<table>
<tr>
<td><img src="https://github.com/kokekanon/OTredemption-Picture-NODELETE/blob/main/Picture/Android/001_ingame.png?raw=true" width="200"></td>
<td><img src="https://github.com/kokekanon/OTredemption-Picture-NODELETE/blob/main/Picture/Android/001_interface.png?raw=true" width="200"></td>
<td><img src="https://github.com/kokekanon/OTredemption-Picture-NODELETE/blob/main/Picture/Android/003_patrikq.jpg?raw=true" width="270"></td>
</tr>
<tr>
<td align="center">Interface</td>
<td align="center">Density Pixel</td>
<td align="center">Joystick</td>
</tr>
</table>
</p>

- Support **HTTP/HTTPS/WS/WSS** — by [@alfuveam](https://github.com/alfuveam)
- Support Tibia 12.85/protobuf by [@Nekiro](https://github.com/nekiro)
- Action Bar — by [@DipSet](https://github.com/Dip-Set1)  
- Access to widget children via `widget.childId` — by [@Hugo0x1337](https://github.com/Hugo0x1337)  
- Shader System Fix *(CTRL + Y)* — by [@FreshyPeshy](https://github.com/FreshyPeshy)

<p align="center">
<table>
<tr>
<td><img src="https://github.com/kokekanon/OTredemption-Picture-NODELETE/blob/main/Picture/Shader/001_creature.gif?raw=true" width="200"></td>
<td><img src="https://github.com/kokekanon/OTredemption-Picture-NODELETE/blob/main/Picture/Shader/003_map.gif?raw=true" width="200"></td>
<td><img src="https://github.com/kokekanon/OTredemption-Picture-NODELETE/blob/main/Picture/Shader/002_mount.gif?raw=true" width="200"></td>
</tr>
<tr>
<td align="center">Creature</td>
<td align="center">Map</td>
<td align="center">Mount</td>
</tr>
</table>
</p>

- Refactored Battle Module — by [@andersonfaaria](https://github.com/andersonfaaria)  
- Health & Mana Circle — by [@EgzoT](https://github.com/EgzoT), [@GustavoBlaze](https://github.com/GustavoBlaze), [@Tekadon58](https://github.com/Tekadon58) • [Project](https://github.com/EgzoT/-OTClient-Mod-health_and_mana_circle)  
- Tibia Theme 1.2 by **Zews** — [Forum Thread](https://otland.net/threads/otc-tibia-theme-v1-2.230988/)  
- Add option `ADJUST_CREATURE_INFORMATION_BASED_ON_CROP_SIZE` in [setup.otml](https://github.com/mehah/otclient/blob/main/data/setup.otml#L24) — by [@SkullzOTS](https://github.com/SkullzOTS)
- **Lua Debugger for VSCode** — [see wiki](https://github.com/mehah/otclient/wiki/Lua-Debugging-(VSCode)) — by [@BenDol](https://github.com/BenDol)  
- **3D Sound and Sound Effects!** — by [@Codinablack](https://github.com/codinablack)

| Example 1 | Example 2 | Example 3 |
|---------|---------|---------|
| <video src="https://github.com/kokekanon/otclient.readme/assets/114332266/4547907a-8eb9-42f5-b445-901cb5270509" width="200" controls></video> | <video src="https://github.com/kokekanon/otclient.readme/assets/114332266/0bb4739f-e902-4370-85dc-e796564aac8e" width="200" controls></video> | <video src="https://github.com/kokekanon/otclient.readme/assets/114332266/95db3fa1-a793-4ab7-86a3-e21a8543a23c" width="200" controls></video> |

#### 💸 Sponsored (Features)
- **Bot V8** — ([@luanluciano93](https://github.com/luanluciano93), [@SkullzOTS](https://github.com/SkullzOTS), [@kokekanon](https://github.com/kokekanon), [@FranciskoKing](https://github.com/FranciskoKing), [@Kizuno18](https://github.com/Kizuno18))  
  - Adapted **85%**  
  - [VS Solution](https://github.com/mehah/otclient/blob/68e4e1b94c2041bd235441244156e6477058250c/vc17/settings.props#L9) / [CMAKE](https://github.com/mehah/otclient/blob/68e4e1b94c2041bd235441244156e6477058250c/src/CMakeLists.txt#L13)

- **Shader with Framebuffer** — ([@SkullzOTS](https://github.com/SkullzOTS), [@Mryukiimaru](https://github.com/Mryukiimaru), [@JeanTheOne](https://github.com/JeanTheOne), [@KizaruHere](https://github.com/KizaruHere))

<p align="center">
<table>
<tr>
<td><img src="https://github.com/kokekanon/OTredemption-Picture-NODELETE/blob/main/Picture/Shader/Framebuffer/001_creature.gif?raw=true" width="200"></td>
<td><img src="https://github.com/kokekanon/OTredemption-Picture-NODELETE/blob/main/Picture/Shader/Framebuffer/002_items.gif?raw=true" width="200"></td>
<td><img src="https://github.com/kokekanon/OTredemption-Picture-NODELETE/blob/main/Picture/Shader/Framebuffer/003_UICreature.gif?raw=true" width="110"></td>
</tr>
<tr>
<td align="center">Creature</td>
<td align="center">Items</td>
<td align="center">UICreature</td>
</tr>
</table>
</p>

- **Full Cyclopedia** — ([@luanluciano93](https://github.com/luanluciano93), [@kokekanon](https://github.com/kokekanon), [@MUN1Z](https://github.com/MUN1Z), [@qatari](https://github.com/qatari))

- **Wheel of Destiny** — (R!ck,ZLukSrT#8740,Christianlb, [@andreoam](https://github.com/andreoam), [@Libergod](https://github.com/libergod))

#### 🔦 OTClient V8 (Features)
- Lighting System  
- Floor Fading  
- Path Finding  
- Module Shop  
- Module Outfit  
- Placeholder  
- UIGraph  
- Keybinds  
- Cam system

---

## <a id="the-mobile-project"></a><img height="20" src="https://raw.githubusercontent.com/github/explore/80688e429a7d4ef2fca1e82350fe8e3517d3494d/topics/android/android.png"/> The Mobile Project
This is a fork of edubart's OTClient. The objective of this fork is to develop a runnable OTClient on mobile devices.

**Tasks**
- [x] Compile on Android devices
- [ ] Compile on Apple devices
- [ ] Adapt the UI reusing the existing LUA code

**Current compiling tutorials**
- [Compiling for Android](https://github.com/mehah/otclient/wiki/Compiling-on-Android)

---

## <a id="compiling"></a>🔨 Compiling
If you are interested in compiling this project, visit the **[Wiki](https://github.com/mehah/otclient/wiki)**.

---

## <a id="docker"></a>🐳 Docker

In order to build the app for production, run the following commands:

**1) Build the image**
```bash
docker build -t mehah/otclient .
```

**2) Run the built image**
```bash
# Disable access control for the X server.
xhost +

# Run the container image with the required bindings to the host devices and volumes.
docker run -it --rm \
  --env DISPLAY \
  --volume /tmp/.X11-unix:/tmp/.X11-unix \
  --device /dev/dri \
  --device /dev/snd mehah/otclient /bin/bash

# Enable access control for the X server.
xhost -
```

---

## <a id="need-help"></a>🩺 Need Help?
Ask questions on **Discord**: https://discord.gg/tUjTBZzMCy

---

## <a id="bugs"></a>📑 Bugs
Found a bug? Please create an issue in our **[bug tracker](https://github.com/mehah/otclient/issues)**.

> [!TIP]
> If using **Nostalrius 7.2**, **Nekiro TFS-1.5-Downgrades-7.72** OR any protocol below **860** and the walking system is **stuttering**, set  
> [`force-new-walking-formula: true`](https://github.com/mehah/otclient/blob/cf7badda978de88cb3724615688e3d9da2ff4207/data/setup.otml#L21) in `data/setup.otml`.  
> In old protocols, if item speed feels too fast, adjust  
> [`item-ticks-per-frame: 75`](https://github.com/mehah/otclient/blob/cf7badda978de88cb3724615688e3d9da2ff4207/data/setup.otml#L32) in `data/setup.otml`.

> if you use TVP or Nostalrius 7.72 activate the feature `g_game.enableFeature(GameTileAddThingWithStackpos)` in game_feature .

---

## <a id="roadmap"></a>❤️ Roadmap
| TO-DO list | Status | PR |
|---|---|---|
| Sound tibia 13 | ![](https://geps.dev/progress/80) | [#1098](https://github.com/mehah/otclient/pull/1098) |
| Prey and tasks | ![](https://geps.dev/progress/10) | [#1380](https://github.com/mehah/otclient/pull/1380) |
| Compendium | ![](https://geps.dev/progress/15) | [#1625](https://github.com/mehah/otclient/pull/1625) |
| Party List | ![](https://geps.dev/progress/0) | None |
| Proficiency | ![](https://geps.dev/progress/80) | [#1593](https://github.com/mehah/otclient/pull/1593) |
| New Imbui 15x/14x | ![](https://geps.dev/progress/80) | [#1616](https://github.com/mehah/otclient/pull/1616) |

---

## <a id="support-protocol"></a>💯 Support Protocol

| Protocol / version | Description | Required Feature | Compatibility |
|---|---|---|---|
| TFS (7.72) | Downgrade nekiro / Nostalrius | [force-new-walking-formula: true](https://github.com/mehah/otclient/blob/cf7badda978de88cb3724615688e3d9da2ff4207/data/setup.otml#L21) • [item-ticks-per-frame: 500](https://github.com/mehah/otclient/blob/cf7badda978de88cb3724615688e3d9da2ff4207/data/setup.otml#L32) | ✅ |
| TFS 0.4 (8.6) | Fir3element | [item-ticks-per-frame: 500](https://github.com/mehah/otclient/blob/cf7badda978de88cb3724615688e3d9da2ff4207/data/setup.otml#L32) | ✅ |
| TFS 1.5 (8.0 / 8.60) | Downgrade nekiro / MillhioreBT | [force-new-walking-formula: true](https://github.com/mehah/otclient/blob/cf7badda978de88cb3724615688e3d9da2ff4207/data/setup.otml#L21) • [item-ticks-per-frame: 500](https://github.com/mehah/otclient/blob/cf7badda978de88cb3724615688e3d9da2ff4207/data/setup.otml#L32) | ✅ |
| TFS 1.4.2 (10.98) | Release Otland |  | ✅ |
| TFS 1.6 (13.10) | Main repo otland (2024) | [See wiki](https://github.com/mehah/otclient/wiki/Tutorial-to-Use-OTC-in-TFS-main) | ✅ |
| Canary (13.21 / 13.32 / 13.40) | OpenTibiaBr | [See Wiki](https://docs.opentibiabr.com/opentibiabr/projects/otclient-redemption/about#how-to-connect-on-canary-with-otclient-redemption) | ✅ |
| Canary (14.00 ~ 14.12) | OpenTibiaBr | [See Wiki](https://docs.opentibiabr.com/opentibiabr/projects/otclient-redemption/about#how-to-connect-on-canary-with-otclient-redemption) | ✅ |
| Canary (15.00 ~ 15.11) | OpenTibiaBr | [See Wiki](https://docs.opentibiabr.com/opentibiabr/projects/otclient-redemption/about#how-to-connect-on-canary-with-otclient-redemption) | ✅ |

---

## <a id="license"></a>©️ License
OTClient is made available under the **MIT License** — you are free to use it for commercial, non-commercial, closed or open projects.  
See: [MIT License](http://opensource.org/licenses/MIT)

---

## <a id="contributors"></a>❤️ Contributors
If you are interested in supporting the project, donate here:  
**[PayPal](https://www.paypal.com/donate/?business=CV9D5JF8E46LY&no_recurring=0&item_name=Thank+you+very+much+for+your+donation.&currency_code=BRL)**
