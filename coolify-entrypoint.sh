#!/usr/bin/env sh
set -eu

# 1) Onboard idempotent (crée les fichiers si absents)
nanobot onboard || true

CFG="/root/.nanobot/config.json"

# 2) Écrit/merge la config depuis les ENV
python3 - <<'PY'
import json, os

cfg_path = "/root/.nanobot/config.json"

provider = os.getenv("NANOBOT_PROVIDER", "openrouter").strip()
model    = os.getenv("NANOBOT_MODEL", "openai/gpt-5.2").strip()

openrouter_key = os.getenv("OPENROUTER_API_KEY", "").strip()
if provider == "openrouter" and not openrouter_key:
    raise SystemExit("ERROR: OPENROUTER_API_KEY is required when NANOBOT_PROVIDER=openrouter")

max_tokens      = int(os.getenv("NANOBOT_MAX_TOKENS", "8192"))
temperature     = float(os.getenv("NANOBOT_TEMPERATURE", "0.1"))
max_tool_iters  = int(os.getenv("NANOBOT_MAX_TOOL_ITERATIONS", "40"))
memory_window   = int(os.getenv("NANOBOT_MEMORY_WINDOW", "100"))

gw_host         = os.getenv("NANOBOT_GATEWAY_HOST", "0.0.0.0")
gw_port         = int(os.getenv("NANOBOT_GATEWAY_PORT", "18790"))
hb_enabled      = os.getenv("NANOBOT_HEARTBEAT_ENABLED", "true").lower() in ("1","true","yes","on")
hb_interval     = int(os.getenv("NANOBOT_HEARTBEAT_INTERVAL_S", "1800"))

# Optional: Brave search (si tu veux activer l’outil web nanobot)
brave_key       = os.getenv("BRAVE_API_KEY", "").strip()
brave_max       = int(os.getenv("BRAVE_MAX_RESULTS", "5"))

with open(cfg_path, "r", encoding="utf-8") as f:
    cfg = json.load(f)

cfg.setdefault("agents", {}).setdefault("defaults", {})
cfg["agents"]["defaults"].update({
    "provider": provider,
    "model": model,
    "maxTokens": max_tokens,
    "temperature": temperature,
    "maxToolIterations": max_tool_iters,
    "memoryWindow": memory_window,
})

cfg.setdefault("providers", {})
if provider == "openrouter":
    cfg["providers"].setdefault("openrouter", {})
    cfg["providers"]["openrouter"]["apiKey"] = openrouter_key

cfg.setdefault("gateway", {})
cfg["gateway"].update({
    "host": gw_host,
    "port": gw_port,
    "heartbeat": {
        "enabled": hb_enabled,
        "intervalS": hb_interval
    }
})

if brave_key:
    cfg.setdefault("tools", {}).setdefault("web", {}).setdefault("search", {})
    cfg["tools"]["web"]["search"]["apiKey"] = brave_key
    cfg["tools"]["web"]["search"]["maxResults"] = brave_max

with open(cfg_path, "w", encoding="utf-8") as f:
    json.dump(cfg, f, indent=2, ensure_ascii=False)

print("Config patched OK:", cfg_path)
print("Provider:", provider)
print("Model:", model)
PY

# 3) Démarre la gateway
exec nanobot gateway
