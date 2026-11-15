#!/usr/bin/env python3
"""Turn off Obsidian Restricted mode for one vault by pre-seeding the per-vault
`enable-plugin-<vaultId>` localStorage key (Chromium LevelDB log append, no deps).
Registers the vault in obsidian.json if missing. Obsidian must be closed (LevelDB lock);
otherwise exits 3 and changes nothing. Usage: obsidian-trust-vault.py <vault_dir> [--ldb DIR] [--json FILE] [--force]
"""
import hashlib, json, os, struct, subprocess, sys, time

KEY_PREFIX = b"_app://obsidian.md\x00\x01enable-plugin-"

_T = []
for _i in range(256):
    _c = _i
    for _ in range(8):
        _c = (_c >> 1) ^ (0x82F63B78 if _c & 1 else 0)
    _T.append(_c)


def crc32c(b):
    c = 0xFFFFFFFF
    for x in b:
        c = _T[(c ^ x) & 0xFF] ^ (c >> 8)
    return c ^ 0xFFFFFFFF


def masked(c):
    return (((c >> 15) | (c << 17)) + 0xA282EAD8) & 0xFFFFFFFF


def varint(n):
    out = bytearray()
    while n >= 128:
        out.append((n & 127) | 128)
        n >>= 7
    out.append(n)
    return bytes(out)


def last_seq_and_count(data):
    """Walk the log; verify each record's CRC; return next sequence number."""
    i, nxt = 0, 1
    while i + 7 <= len(data):
        crc, ln, t = struct.unpack("<IHB", data[i:i + 7])
        body = data[i + 7:i + 7 + ln]
        if len(body) < ln or masked(crc32c(bytes([t]) + body)) != crc:
            raise SystemExit("leveldb log CRC mismatch, refusing to write")
        if t == 1 and len(body) >= 12:
            seq, cnt = struct.unpack("<QI", body[:12])
            nxt = seq + cnt
        elif t != 1:
            raise SystemExit("fragmented leveldb record, refusing to write")
        i += 7 + ln
        # records never straddle 32KiB blocks only if padded; bail if block padding is present
        if (i % 32768) > 32768 - 7 and i < len(data):
            raise SystemExit("block boundary reached, refusing to write")
    return nxt


def obsidian_running():
    try:
        out = subprocess.run(["tasklist", "/FI", "IMAGENAME eq Obsidian.exe", "/NH"],
                             capture_output=True, text=True).stdout
        return "Obsidian.exe" in out
    except Exception:
        return False


def main():
    a = sys.argv[1:]
    if not a:
        raise SystemExit(__doc__)
    vault = os.path.normpath(os.path.abspath(a[0]))
    appdata = os.environ.get("APPDATA", "")
    ldb = a[a.index("--ldb") + 1] if "--ldb" in a else os.path.join(appdata, "obsidian", "Local Storage", "leveldb")
    oj = a[a.index("--json") + 1] if "--json" in a else os.path.join(appdata, "obsidian", "obsidian.json")
    force = "--force" in a
    if not force and obsidian_running():
        print("obsidian-trust-vault: Obsidian is running; close it and re-run (or toggle Restricted mode off once in the UI)")
        return 3
    try:
        cfg = json.load(open(oj, encoding="utf-8"))
    except Exception:
        cfg = {}
    vaults = cfg.setdefault("vaults", {})
    vid = next((k for k, v in vaults.items() if os.path.normpath(v.get("path", "")).lower() == vault.lower()), None)
    if not vid:
        vid = hashlib.sha1(vault.encode()).hexdigest()[:16]
        vaults[vid] = {"path": vault, "ts": int(time.time() * 1000)}
        os.makedirs(os.path.dirname(oj), exist_ok=True)
        json.dump(cfg, open(oj, "w", encoding="utf-8"))
    logs = sorted(f for f in os.listdir(ldb) if f.endswith(".log"))
    if not logs:
        raise SystemExit("no leveldb .log file found")
    path = os.path.join(ldb, logs[-1])
    data = open(path, "rb").read()
    seq = last_seq_and_count(data)
    key = KEY_PREFIX + vid.encode()
    batch = struct.pack("<QI", seq, 1) + b"\x01" + varint(len(key)) + key + varint(5) + b"\x01true"
    rec = struct.pack("<IHB", masked(crc32c(b"\x01" + batch)), len(batch), 1) + batch
    with open(path, "ab") as f:
        f.write(rec)
    print(f"obsidian-trust-vault: enabled community plugins for vault {vid} ({vault})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
