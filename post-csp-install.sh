#!/bin/bash
# post-csp-install.sh — re-run after EVERY CSP install/update.
# CSP's zip extraction resets these Linux-specific settings each time, so without
# re-running this you'll chase the same crashes after every update.
set -e

AC="$HOME/.steam/steam/steamapps/common/assettocorsa"
EXT="$AC/extension/config"

# WeatherFX ON — required for Pure, and many online servers require it.
sed -i 's/^ENABLED=0/ENABLED=1/' "$EXT/weather_fx.ini"

# DXGI flip model OFF — DXVK's vtable differs from native DXGI; CSP's hook crashes with it on.
sed -i '/^\[BASIC\]/,/^\[/ s/^ENABLED=1/ENABLED=0/' "$EXT/dxgi_tweaks.ini"

# Remove [NAMES_WINE] — stale Wine symbol overrides break CSP init.
python3 - "$EXT/data_alt_mapping.ini" <<'PY'
import re, sys
p = sys.argv[1]
open(p, "w").write(re.sub(r"\n\[NAMES_WINE\].*", "", open(p).read(), flags=re.DOTALL))
PY

# Delete stale memory-layout cache — forces a clean rebuild.
rm -f "$AC/cache/memory_layout.bin"

echo "post-CSP Linux fixes applied (WeatherFX on, DXGI flip off, NAMES_WINE removed, cache cleared)."
