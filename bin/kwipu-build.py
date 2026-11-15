# One-off first build of the Kwipu graph for a vault, outside MCP (no 30s client timeout, no nested-async quirk).
import os, sys
sys.path.insert(0, os.path.expanduser("~/.claude-tools/Kwipu"))
os.environ["KWIPU_KNOWLEDGE_DIR"] = sys.argv[1]
os.environ.setdefault("KWIPU_LLM_MODEL", "qwen3-coder:30b-a3b-q4_K_M")
os.environ.setdefault("KWIPU_EMBED_MODEL", "nomic-embed-text")
os.environ.setdefault("KWIPU_OLLAMA_TIMEOUT", "1800")  # big first builds queue behind other GPU users; the 300 s default read-times-out
import kwipu_mcp_server as k
k._get_rag()
print("BUILD DONE")
