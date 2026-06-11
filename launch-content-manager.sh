#!/bin/bash
# Run Content Manager in its OWN Wine prefix (~/.wine-cm), isolated from the Proton
# prefix Assetto Corsa runs in. This keeps CM's .NET / Mono / Steam-bridge files out
# of the game runtime prefix, which avoids a whole class of CSP/Proton weirdness.
#
# Use this for MOD MANAGEMENT ONLY. Launch actual online sessions with launch-ac.sh
# (CM's server browser crashes under Wine anyway).

export WINEPREFIX="$HOME/.wine-cm"
WINE="${WINE:-wine}"   # set WINE=/path/to/wine64 to use a specific Wine build
AC="$HOME/.steam/steam/steamapps/common/assettocorsa"

# --- First-time setup (run these once to build the prefix + deps CM needs) ---
#   WINEPREFIX="$HOME/.wine-cm" winecfg                          # creates the prefix
#   WINEPREFIX="$HOME/.wine-cm" winetricks -q dotnet48 corefonts # CM needs .NET 4.8
#
# Use "Content Manager Safe.exe" (hardware acceleration off) — the normal CM exe
# tends to crash on Wine's renderer. In CM you can enable Safe mode, or just copy/
# rename "Content Manager.exe" -> "Content Manager Safe.exe" in the AC folder.

exec "$WINE" "$AC/Content Manager Safe.exe"
