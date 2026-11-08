#!/usr/bin/env python3
"""Extract AltStore-shaped appPermissions from an unsigned .app.

Reads NS*UsageDescription privacy strings from Info.plist and entitlements
from the main binary's embedded __TEXT,__entitlements section (magic
0xFADE7171). Writes an AltStore 2024+ nested-shape JSON dict to the output
path, or `{}` when no permissions are declared.

Output shape:
    {
      "entitlements": ["com.apple.developer.icloud-services", ...],
      "privacy": {
        "NSCameraUsageDescription": "Why we need the camera.",
        ...
      }
    }

Team-identifying entitlements (application-identifier, team-identifier)
are dropped so the source does not leak a signing team id.
"""
from __future__ import annotations

import json
import plistlib
import re
import struct
import sys
from pathlib import Path

ENTITLEMENTS_MAGIC = 0xFADE7171
TEAM_LEAKING = {
    "application-identifier",
    "com.apple.developer.team-identifier",
}


def read_privacy(info_plist: Path) -> dict[str, str]:
    with info_plist.open("rb") as f:
        plist = plistlib.load(f)
    return {k: v for k, v in plist.items() if k.startswith("NS") and k.endswith("UsageDescription")}


def read_entitlements(binary: Path) -> list[str]:
    """Scan the Mach-O binary for the embedded entitlements XML blob."""
    data = binary.read_bytes()
    needle = struct.pack(">I", ENTITLEMENTS_MAGIC)
    idx = data.find(needle)
    if idx == -1:
        return []
    # Blob header: magic (u32 BE), length (u32 BE). Payload is the XML plist.
    length = struct.unpack(">I", data[idx + 4 : idx + 8])[0]
    payload = data[idx + 8 : idx + length]
    # Trim trailing NULs left by the signer.
    payload = payload.rstrip(b"\x00")
    try:
        ents = plistlib.loads(payload)
    except plistlib.InvalidFileException:
        return []
    return sorted(k for k in ents if k not in TEAM_LEAKING)


def main() -> int:
    if len(sys.argv) != 3:
        print("usage: extract_permissions.py <App.app> <out.json>", file=sys.stderr)
        return 2
    app = Path(sys.argv[1])
    out = Path(sys.argv[2])

    info = app / "Info.plist"
    privacy = read_privacy(info) if info.exists() else {}

    exec_name = plistlib.loads(info.read_bytes()).get("CFBundleExecutable") if info.exists() else None
    entitlements: list[str] = []
    if exec_name:
        binary = app / exec_name
        if binary.exists():
            entitlements = read_entitlements(binary)

    permissions: dict[str, object] = {}
    if entitlements:
        permissions["entitlements"] = entitlements
    if privacy:
        permissions["privacy"] = privacy

    out.write_text(json.dumps(permissions, indent=2, sort_keys=True))
    print(f"appPermissions: {len(entitlements)} entitlements, {len(privacy)} privacy keys")
    return 0


if __name__ == "__main__":
    sys.exit(main())
