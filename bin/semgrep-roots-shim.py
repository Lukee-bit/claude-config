#!/usr/bin/env python3
"""Run `semgrep mcp` and answer its roots/list requests itself (mcptoon's client does not), so scans do not hang."""
import json, os, subprocess, sys, threading
p = subprocess.Popen([os.path.expanduser("~/.local/bin/semgrep" + (".exe" if os.name == "nt" else "")), "mcp", *sys.argv[1:]],
                     stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=sys.stderr, bufsize=0)
lock = threading.Lock()
def to_server(b):
    with lock:
        p.stdin.write(b); p.stdin.flush()
def pump_in():
    for line in sys.stdin.buffer:
        to_server(line)
    p.stdin.close()
threading.Thread(target=pump_in, daemon=True).start()
for line in iter(p.stdout.readline, b""):
    try:
        m = json.loads(line)
    except ValueError:
        m = None
    if isinstance(m, dict) and m.get("method") == "roots/list":
        to_server((json.dumps({"jsonrpc": "2.0", "id": m["id"], "result": {"roots": []}}) + "\n").encode())
        continue
    sys.stdout.buffer.write(line); sys.stdout.buffer.flush()
sys.exit(p.wait())
