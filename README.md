# Assetto Corsa + CSP + Pure on Linux (Proton / Wine)

A working, **confirmed** recipe for running **Assetto Corsa** with **Custom Shaders Patch (CSP) 0.2.x**, **Pure** weather, **ReShade**, force-feedback wheels, and **online multiplayer with WeatherFX** on Linux via Steam Proton.

> **TL;DR — the one thing nobody tells you:** use **GE-Proton9-20 (Wine 9.0)**, *not* GE-Proton10 / Wine 10+. Wine 10 added a memory protection (W^X) that silently breaks CSP's patcher. Everything else here falls into place once the patcher actually runs.

---

## Why "Failed to initialize" happens (and the real fix)

CSP works by patching functions inside `acs.exe` at runtime. To do that it has to write into executable memory.

**Wine 10.0+ added W^X memory protection** (`set_page_vprot_exec_write_protect`) that blocks writing to pages marked executable. CSP's patcher hits this wall and silently fails — you get **"Failed to initialize"** every single launch, on every CSP version, no matter what else you change.

**Wine 9.0 doesn't enforce it.** On **GE-Proton9-20**, CSP patches all **2373** functions cleanly and reports *"CSP Available."* This is the root cause behind the vast majority of "CSP won't load on Linux" reports — it's the Proton version, not your config.

---

## Test system (confirmed working)

| | |
|---|---|
| **OS** | Ubuntu 24.04.4 LTS (Noble) |
| **Kernel** | 6.11.0-29-generic |
| **CPU** | Intel Core i7-6700K @ 4.0 GHz *(2015)* |
| **RAM** | 32 GB |
| **GPU** | NVIDIA GTX 1080 8 GB — driver 580.159.03 *(2016)* |
| **Proton** | GE-Proton9-20 (Wine 9.0 Staging) |
| **AC / CSP / Pure** | 1.16.4 / 0.2.12-preview1 (build 3467) / 2.57 |

Not a bleeding-edge machine — a 2015 CPU and 2016 GPU. If it runs here, it'll run on most modern Linux gaming setups.

---

## 1. Install GE-Proton9-20

Install it with [**ProtonUp-Qt**](https://github.com/DavidoTek/ProtonUp-Qt) (or drop it in `~/.steam/steam/compatibilitytools.d/`).

In Steam → Assetto Corsa → **Properties → Compatibility → Force GE-Proton9-20** — or set it via the launch script below.

> ⚠️ **Do not use GE-Proton10 / any Wine 10 build.** That's the W^X wall.

## 2. Launch script

This bypasses Content Manager for launching, kills any stale `wineserver`, sets `HideWineExports=Y` (which makes Wine **hide** `wine_get_version` — so CSP's `GetProcAddress` returns NULL and CSP thinks it's on **native Windows**, keeping its Wine-specific code paths off), and launches AC. **Edit the flagged lines for your hardware.**

```bash
#!/bin/bash
export STEAM_COMPAT_CLIENT_INSTALL_PATH="$HOME/.steam/debian-installation"
export STEAM_COMPAT_DATA_PATH="$HOME/.steam/steam/steamapps/compatdata/244210"
export WINEPREFIX="$STEAM_COMPAT_DATA_PATH/pfx"

# NVIDIA Prime — laptop / hybrid (multi-GPU) only. DELETE on a single-GPU desktop.
export __NV_PRIME_RENDER_OFFLOAD=1
export __GLX_VENDOR_LIBRARY_NAME=nvidia

# dwrite=n,b is what LOADS CSP (native CSP dwrite.dll before Wine's builtin).
# msvcp120/msvcr120=n,b avoids crashes from Wine's MSVC runtime missing symbols.
export WINEDLLOVERRIDES="dwrite=n,b;msvcp120=n,b;msvcr120=n,b"

# Your wheel's VID/PID. Moza R5 shown — swap for yours, or remove if no wheel.
# Without this the wheel shows up as a generic gamepad and FFB won't initialize.
export SDL_JOYSTICK_WHEEL_DEVICES=0x346e/0x0004

GE="$HOME/.steam/steam/compatibilitytools.d/GE-Proton9-20"
AC="$HOME/.steam/steam/steamapps/common/assettocorsa"

# kill stale wineserver; HideWineExports=Y hides wine_get_version so CSP can't
# detect Wine and treats this as native Windows
"$GE/files/bin/wineserver" -k 2>/dev/null ; sleep 1
WINEFSYNC=1 "$GE/files/bin/wine64" reg add "HKCU\\Software\\Wine" \
    /v HideWineExports /t REG_SZ /d "Y" /f 2>/dev/null

exec "$GE/proton" run "$AC/AssettoCorsa_original.exe"
```

Save as `launch-ac.sh`, `chmod +x launch-ac.sh`, run it. (Also in this repo as [`launch-ac.sh`](launch-ac.sh).)

## 3. Install CSP + Pure

Install [**Content Manager**](https://acstuff.club/) first, then **CSP 0.2.12-preview1** (from CM → Settings → Custom Shaders Patch), then **Pure 2.57** last. Run CM in its own isolated prefix — see [Content Manager (separate prefix)](#content-manager--run-it-in-its-own-prefix). Sources are in [Tools & sources](#tools--sources) below.

> Run **Content Manager in its own throwaway Wine prefix** (e.g. `~/.wine-cm`) for mod management only — don't use it to launch online sessions, and keep it out of the Proton prefix.

## 4. Post-install fixes — run after EVERY CSP update

CSP's zip extraction **resets these settings on every install/update**, so re-run this script each time or you'll chase the same issues forever.

```bash
#!/bin/bash
# post-csp-install.sh
AC="$HOME/.steam/steam/steamapps/common/assettocorsa"
EXT="$AC/extension/config"

# WeatherFX ON — required for Pure, and many online servers require it
sed -i 's/^ENABLED=0/ENABLED=1/' "$EXT/weather_fx.ini"

# DXGI flip model OFF — DXVK's vtable differs from native DXGI; CSP's hook crashes with it on
sed -i '/^\[BASIC\]/,/^\[/ s/^ENABLED=1/ENABLED=0/' "$EXT/dxgi_tweaks.ini"

# Remove [NAMES_WINE] — stale Wine symbol overrides break CSP init
python3 - "$EXT/data_alt_mapping.ini" <<'PY'
import re, sys
p = sys.argv[1]
open(p, "w").write(re.sub(r"\n\[NAMES_WINE\].*", "", open(p).read(), flags=re.DOTALL))
PY

# Delete stale memory-layout cache — forces a clean rebuild
rm -f "$AC/cache/memory_layout.bin"

echo "post-CSP fixes applied."
```

(Also in this repo as [`post-csp-install.sh`](post-csp-install.sh).)

## 5. Physics threads — `THREADS=0` and lock it

In `system/cfg/assetto_corsa.ini` set **`THREADS=0`**, then make it read-only so Content Manager can't reset it:

```bash
chmod 444 ~/.steam/steam/steamapps/common/assettocorsa/system/cfg/assetto_corsa.ini
```

> `THREADS=1` crashes the physics thread under Wine after **~67 seconds**, every time. `THREADS=0` (physics on the main thread) fixes it.

Also set `UPDATE_HZ=50` in `cfg/network.ini` for smoother online.

## 6. Wheel + force feedback

| | |
|---|---|
| **Wheel (example)** | Moza R5 — VID `0x346e` / PID `0x0004` |
| **SDL fix** | `SDL_JOYSTICK_WHEEL_DEVICES=0x346e/0x0004` in the launch script — **without it the wheel registers as a generic gamepad and FFB won't initialize** |
| **Steering lock** | `LOCK=900` in `controls.ini` (R5 max is 1080°; 900° gives full authority in most cars) |
| **FFB filter** | `FILTER_FF=0.15` (the default `0.99` kills all road/kerb detail) · FFB gain `1.0` |

Find your wheel's VID/PID with `lsusb`.

## 7. Connecting to a server

Once CSP loads, launch AC with the script and go **Drive → Online → Direct Connect →** *your server's IP* and game port (default `9600`).

> **Don't use Content Manager's server browser on Linux** — it crashes under Wine 9 (an IOCP socket bug). Direct Connect (or add-server-by-IP) avoids it.

---

## Content Manager — run it in its own prefix

Content Manager is only needed for **mod management** (installing CSP, Pure, cars, tracks). Run it in a **separate Wine prefix** (`~/.wine-cm`) so its .NET / Mono / Steam-bridge files never end up in the Proton prefix the game runs in — a polluted game prefix is a common, hard-to-debug cause of CSP/Proton issues.

First-time setup (once):

```bash
WINEPREFIX="$HOME/.wine-cm" winecfg                          # create the prefix
WINEPREFIX="$HOME/.wine-cm" winetricks -q dotnet48 corefonts # CM needs .NET 4.8
```

Then launch CM with [`launch-content-manager.sh`](launch-content-manager.sh) — it sets `WINEPREFIX="$HOME/.wine-cm"` and runs **`Content Manager Safe.exe`** (hardware acceleration off, which dodges Wine's renderer crashes).

> The two prefixes share **nothing** except the read-only game folder (`…/common/assettocorsa/`) — and that's correct: it's the actual game content (cars/tracks/CSP), not a Wine prefix. Don't launch online sessions from CM — use [`launch-ac.sh`](launch-ac.sh).

## ReShade

**[ReShade](https://reshade.me) works — leave `d3d11.dll` in place.** Old guides that say "remove ReShade before using CSP" are wrong. Those crashes came from CSP being in a *failed / partial patcher state* (Wine 10 W^X), not from ReShade itself. With CSP patched cleanly on Wine 9, the D3D11 hook chain is complete end-to-end and ReShade attaches on top of it with no conflict.

## Known Linux quirks (you didn't break anything)

- **CSP app shelf icons invisible** when you press **Home** — the debug console shows instead. Cosmetic Wine IMGUI issue, doesn't affect gameplay or weather.
- **Content Manager server browser crashes** under Wine 9 (IOCP socket bug) — use Direct Connect.
- **"Safe mode?" prompt** on first load after a crash — cosmetic, CSP still loads fully.

## For server admins (AssettoServer)

If you run an [AssettoServer](https://github.com/compujuckel/AssettoServer) and want CSP clients to get WeatherFX/Pure online, set these in `extra_cfg.yml`:

```yaml
EnableClientMessages: true
EnableWeatherFx: true
```

Without `EnableWeatherFx`, a CSP+Pure client **crashes on join** with *"server requires active WeatherFX."* Note that enabling `EnableClientMessages` makes the server **CSP-only** (non-CSP clients get kicked).

---

## Tools & sources

Everything here is from its original home — nothing is rehosted:

| Tool | Where to get it |
|---|---|
| **Assetto Corsa** | [Steam (app 244210)](https://store.steampowered.com/app/244210/Assetto_Corsa/) |
| **Content Manager** | [acstuff.club](https://acstuff.club/) (x4fab) |
| **Custom Shaders Patch (CSP)** | [acstuff.club/patch](https://acstuff.club/patch/) (x4fab) — or from inside CM |
| **Pure** (weather/PP) | [Overtake.gg](https://www.overtake.gg/) — search "Pure" (Peter Boese); free + Patreon versions |
| **ReShade** | [reshade.me](https://reshade.me) |
| **GE-Proton** | [github.com/GloriousEggroll/proton-ge-custom](https://github.com/GloriousEggroll/proton-ge-custom) |
| **ProtonUp-Qt** (installs GE-Proton) | [github.com/DavidoTek/ProtonUp-Qt](https://github.com/DavidoTek/ProtonUp-Qt) |
| **AssettoServer** (for admins) | [github.com/compujuckel/AssettoServer](https://github.com/compujuckel/AssettoServer) |

Found a fix for your distro / GPU / wheel? **PRs welcome** — that's the point of putting this on GitHub.

## Credits

Thanks to **x4fab** (CSP, Content Manager), **Peter Boese** (Pure), **GloriousEggroll** (GE-Proton), and the AssettoServer + AC-on-Linux communities for the tools and the collective debugging that made this recipe possible.

## License

[MIT](LICENSE) — copy, fork, adapt freely.
