#!/bin/bash
# Launch Assetto Corsa with CSP under GE-Proton9-20 (Wine 9.0).
# Why Wine 9: Wine 10+ enforces W^X memory protection that blocks CSP's patcher.
# Edit the lines marked "EDIT" for your hardware, then: chmod +x launch-ac.sh && ./launch-ac.sh

export STEAM_COMPAT_CLIENT_INSTALL_PATH="$HOME/.steam/debian-installation"
export STEAM_COMPAT_DATA_PATH="$HOME/.steam/steam/steamapps/compatdata/244210"
export WINEPREFIX="$STEAM_COMPAT_DATA_PATH/pfx"

# EDIT: NVIDIA Prime — laptop / hybrid (multi-GPU) only. DELETE these two on a single-GPU desktop.
export __NV_PRIME_RENDER_OFFLOAD=1
export __GLX_VENDOR_LIBRARY_NAME=nvidia

# dwrite=n,b is what LOADS CSP (native CSP dwrite.dll before Wine's builtin).
# msvcp120/msvcr120=n,b avoids crashes from Wine's MSVC runtime missing symbols.
export WINEDLLOVERRIDES="dwrite=n,b;msvcp120=n,b;msvcr120=n,b"

# EDIT: your wheel's VID/PID (find it with `lsusb`). Moza R5 shown. Remove if you have no wheel.
# Without this the wheel registers as a generic gamepad and FFB won't initialize.
export SDL_JOYSTICK_WHEEL_DEVICES=0x346e/0x0004

GE="$HOME/.steam/steam/compatibilitytools.d/GE-Proton9-20"
AC="$HOME/.steam/steam/steamapps/common/assettocorsa"

# Kill any stale wineserver, then set HideWineExports so CSP's Wine-detection check passes.
"$GE/files/bin/wineserver" -k 2>/dev/null ; sleep 1
WINEFSYNC=1 "$GE/files/bin/wine64" reg add "HKCU\\Software\\Wine" \
    /v HideWineExports /t REG_SZ /d "Y" /f 2>/dev/null

exec "$GE/proton" run "$AC/AssettoCorsa_original.exe"
