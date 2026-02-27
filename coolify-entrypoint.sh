#!/usr/bin/env bash
set -euo pipefail

nanobot onboard || true

CFG=/root/.nanobot/config.json

python - <<'PY'
import json, os

cfg_path = "/root/.nanobot/config.json"

provider = os.getenv("NANOBOT_PROVIDER", "openai").strip()
model    = os.getenv("NANOBOT_MODEL", "gpt-5.2").strip()

openai_key     = os.getenv("OPENAI_API_KEY", "").strip()
openrouter_key = os.getenv("OPENROUTER_API_KEY", "").strip()

max_tokens = int(os.getenv("NANOBOT_MAX_TOKENS", "8192"))
temp = float(os.getenv("NANOBOT_TEMPERATURE", "0.1"))
max_tool_iters = int(os.getenv("NANOBOT_MAX_TOOL_ITERATIONS", "40"))
mem_window = int(os.getenv("NANOBOT_MEMORY_WINDOW", "100"))

gw_host = os.getenv("NANOBOT_GATEWAY_HOST", "0.0.0.0")
gw_port = int(os.getenv("NANOBOT_GATEWAY_PORT", "18790"))
hb_enabled = os.getenv("NANOBOT_HEARTBEAT_ENABLED", "true").lower() in ("1","true","yes","on")
hb_interval = int(os.getenv("NANOBOT_HEARTBEAT_INTERVAL_S", "1800"))

brave_key = os.getenv("BRAVE_API_KEY", "").strip()
brave_max = int(os.getenv("BRAVE_MAX_RESULTS", "5"))

with open(cfg_path, "r", encoding="utf-8") as f:
    cfg = json.load(f)

cfg.setdefault("agents", {}).setdefault("defaults", {})
cfg["agents"]["defaults"].update({
    "provider": provider,
    "model": model,
    "maxTokens": max_tokens,
    "temperature": temp,
    "maxToolIterations": max_tool_iters,
    "memoryWindow": mem_window,
})

cfg.setdefault("providers", {})

if provider == "openai":
    if not openai_key:
        raise SystemExit("ERROR: OPENAI_API_KEY is required when NANOBOT_PROVIDER=openai")
    cfg.setdefault("providers", {}).setdefault("openai", {})
    cfg["providers"]["openai"]["apiKey"] = openai_key

elif provider == "openrouter":
    if not openrouter_key:
        raise SystemExit("ERROR: OPENROUTER_API_KEY is required when NANOBOT_PROVIDER=openrouter")
    cfg.setdefault("providers", {}).setdefault("openrouter", {})
    cfg["providers"]["openrouter"]["apiKey"] = openrouter_key

else:
    raise SystemExit(f"ERROR: Unsupported NANOBOT_PROVIDER={provider} (use openai or openrouter)")

cfg.setdefault("gateway", {})
cfg["gateway"]["host"] = gw_host
cfg["gateway"]["port"] = gw_port
cfg.setdefault("gateway", {}).setdefault("heartbeat", {})
cfg["gateway"]["heartbeat"]["enabled"] = hb_enabled
cfg["gateway"]["heartbeat"]["intervalS"] = hb_interval

cfg.setdefault("tools", {}).setdefault("web", {}).setdefault("search", {})
if brave_key:
    cfg["tools"]["web"]["search"]["apiKey"] = brave_key
cfg["tools"]["web"]["search"]["maxResults"] = brave_max

with open(cfg_path, "w", encoding="utf-8") as f:
    json.dump(cfg, f, indent=2, ensure_ascii=False)

print(f"[entrypoint] provider={provider} model={model} gateway={gw_host}:{gw_port}")
PY

exec nanobot gateway
