---
name: aatos-agent-sync
description: Keep aatos-agent private repo in sync with hermes-agent upstream. Fetch latest commits from hermes-agent, rebrand Hermes->Aatos (strict case rules), and push to aatos-agent private repo. Always use gh auth token from ~/.hermes/.env via git HTTPS.
version: 2.0.0
author: Aatos Agent
license: MIT
metadata:
  aatos:
    tags: [GitHub, Sync, Rebrand, Hermes, Aatos]
    related_skills: [github-auth, github-repo-management, github-pr-workflow]
---

# Aatos Agent Sync & Rebrand Skill

Sync hermes-agent upstream to aatos-agent private repo with a full hermes->aatos rebrand.

## Workflow (ALWAYS follow in order)

1. **Auth**: Get token from `~/.hermes/.env` (`GITHUB_TOKEN`)
2. **Check updates**: Fetch hermes-agent and compare tips
3. **Merge if needed**: Fast-forward or merge hermes-agent/main into aatos-agent
4. **Rebrand**: Full hermes->aatos sweep across all files
5. **Push**: Push to aatos-agent GitHub

**Working directory**: `/root/aatos-agent` (NOT /root/hermes-agent)

---

## Step 1: Auth & Check Remote State

```bash
cd /root/aatos-agent
GITHUB_TOKEN=$(grep "GITHUB_TOKEN=" ~/.hermes/.env | cut -d= -f2 | tr -d '\n\r')

# Ensure hermes-agent remote exists (aatos-agent remote is 'origin')
git remote add hermes-agent https://aatos-git-collab:$GITHUB_TOKEN@github.com/aatos-git-collab/hermes-agent.git 2>/dev/null || true
git fetch hermes-agent main
echo "hermes-agent tip: $(git rev-parse hermes-agent/main | cut -c1-8)"
echo "aatos-agent tip:  $(git rev-parse origin/main | cut -c1-8)"
```

## Step 2: Check If Update Needed

```bash
LOCAL=$(git rev-parse origin/main)
UPSTREAM=$(git rev-parse hermes-agent/main)
if [ "$LOCAL" != "$UPSTREAM" ]; then
  echo "UPDATE AVAILABLE — hermes-agent is $UPSTREAM ahead"
else
  echo "ALREADY UP TO DATE"
fi
```

## Step 3: Merge New hermes-agent Commits

```bash
cd /root/aatos-agent
git fetch hermes-agent
git merge hermes-agent/main -m "sync: merge hermes-agent latest into aatos-agent"
# If merge says "Already up-to-date", that's fine — no new commits to merge
```

## Step 4: Full Rebrand (Python script — run after every merge)

```python
import os, re

root = "/root/aatos-agent"
SKIP_DIRS = {'.git', '__pycache__', 'node_modules', '.venv', 'venv', 'website/node_modules'}

def replace_in_file(filepath):
    try:
        with open(filepath, 'r', encoding='utf-8', errors='replace') as f:
            content = f.read()
    except:
        return False

    new = content

    # === COMPOUND CLASS NAMES (must come FIRST) ===
    new = re.sub(r'\bHermesAgentLoop\b', 'AatosAgentLoop', new)
    new = re.sub(r'\bHermesAgentBaseEnv\b', 'AatosAgentBaseEnv', new)
    new = re.sub(r'\bHermesAgentEnvConfig\b', 'AatosAgentEnvConfig', new)
    new = re.sub(r'\bHermesSweEnv\b', 'AatosSweEnv', new)
    new = re.sub(r'\bHermesToolCallParser\b', 'AatosToolCallParser', new)
    new = re.sub(r'\bHermesTokenStorage\b', 'AatosTokenStorage', new)
    new = re.sub(r'\bHermesACPAgent\b', 'AatosACPAgent', new)
    new = re.sub(r'\bHermesApiServerToolset\b', 'AatosApiServerToolset', new)
    new = re.sub(r'\bHermesBot\b', 'AatosBot', new)
    new = re.sub(r'\bHermesCLI\b', 'AatosCLI', new)
    new = re.sub(r'\bHermesOverlay\b', 'AatosOverlay', new)

    # === MODULE NAMES ===
    new = re.sub(r'\bhermes_cli\b', 'aatos_cli', new)
    new = re.sub(r'\bhermes_constants\b', 'aatos_constants', new)
    new = re.sub(r'\bhermes_state\b', 'aatos_state', new)
    new = re.sub(r'\bhermes_time\b', 'aatos_time', new)
    new = re.sub(r'\bhermes_logging\b', 'aatos_logging', new)
    new = re.sub(r'\bhermes_base_env\b', 'aatos_base_env', new)
    new = re.sub(r'\bhermes_swe_env\b', 'aatos_swe_env', new)
    new = re.sub(r'\bhermes_parser\b', 'aatos_parser', new)
    new = re.sub(r'\bhermes_tools\.py\b', 'aatos_tools.py', new)
    new = re.sub(r'\bhermes_dotenv\b', 'aatos_dotenv', new)

    # === FUNCTION/VAR NAMES ===
    new = re.sub(r'\bhermes_pkce\b', 'aatos_pkce', new)
    new = re.sub(r'\bhermes_version\b', 'aatos_version', new)
    new = re.sub(r'\bhermes_meta\b', 'aatos_meta', new)
    new = re.sub(r'\bhermes_host\b', 'aatos_host', new)
    new = re.sub(r'\bhermes_cfg_path\b', 'aatos_cfg_path', new)
    new = re.sub(r'\bhermes_cfg\b', 'aatos_cfg', new)
    new = re.sub(r'\bhermes_config\b', 'aatos_config', new)
    new = re.sub(r'\bhermes_home_path\b', 'aatos_home_path', new)
    new = re.sub(r'\bhermes_home_resolved\b', 'aatos_home_resolved', new)
    new = re.sub(r'\bhermes_node_bin\b', 'aatos_node_bin', new)
    new = re.sub(r'\bhermes_agent_loop\b', 'aatos_agent_loop', new)
    new = re.sub(r'\bhermes_md\b', 'aatos_md', new)
    new = re.sub(r'\bget_default_hermes_root\b', 'get_default_aatos_root', new)
    new = re.sub(r'\bload_hermes_config\b', 'load_aatos_config', new)
    new = re.sub(r'\bload_hermes_dotenv\b', 'load_aatos_dotenv', new)
    new = re.sub(r'\b_run_hermes_now\b', '_run_aatos_now', new)
    new = re.sub(r'\bhermes_conversation_\b', 'aatos_conversation_', new)
    new = re.sub(r'\.hermes_history\b', '.aatos_history', new)
    new = re.sub(r'\bhermes_test\b', 'aatos_test', new)

    # === INTERNAL CONSTANTS (environments/local.py) ===
    new = re.sub(r'\b_HERMES_PROVIDER_ENV_FORCE_PREFIX\b', '_AATOS_PROVIDER_ENV_FORCE_PREFIX', new)
    new = re.sub(r'\b_HERMES_PROVIDER_ENV_BLOCKLIST\b', '_AATOS_PROVIDER_ENV_BLOCKLIST', new)
    new = re.sub(r'\b_load_hermes_env_vars\b', '_load_aatos_env_vars', new)

    # === ALL-CAPS ENV VARS ===
    for env in [
        'HERMES_HOME', 'HERMES_DIR', 'HERMES_BIN', 'HERMES_CMD', 'HERMES_SKILLS_DIR',
        'HERMES_AGENT_ROOT', 'HERMES_BOT', 'HERMES_VERSION', 'HERMES_AGENT_LOGO',
        'HERMES_CADUCEUS', 'HERMES_WRITE_SAFE_ROOT', 'HERMES_STDOUT',
        'HERMES_RPC_SOCKET', 'HERMES_RPC_DIR',
        'HERMES_MODEL', 'HERMES_PLATFORM', 'HERMES_SESSION_SOURCE',
        'HERMES_GIT_BASH_PATH', 'HERMES_PORTAL_BASE_URL',
        'HERMES_NOUS_MIN_KEY_TTL_SECONDS', 'HERMES_NOUS_TIMEOUT_SECONDS',
        'HERMES_DUMP_REQUESTS', 'HERMES_DUMP_REQUEST_STDOUT',
        'HERMES_API_TIMEOUT', 'HERMES_STREAM_READ_TIMEOUT', 'HERMES_STREAM_STALE_TIMEOUT',
        'HERMES_COPILOT_ACP_COMMAND', 'HERMES_COPILOT_ACP_ARGS',
        'HERMES_CODEX_BASE_URL', 'HERMES_CODEX_REFRESH_TIMEOUT_SECONDS',
        'HERMES_CA_BUNDLE', 'HERMES_QWEN_BASE_URL',
        'HERMES_CRON_TIMEOUT', 'HERMES_CRON_SCRIPT_TIMEOUT',
        'HERMES_CRON_AUTO_DELIVER_PLATFORM', 'HERMES_CRON_AUTO_DELIVER_CHAT_ID', 'HERMES_CRON_AUTO_DELIVER_THREAD_ID',
        'HERMES_CHECKPOINT_TIMEOUT', 'HERMES_HONCHO_HOST', 'HERMES_SPINNER_PAUSE',
        'HERMES_PYTHON', 'HERMES_ENABLE_PROJECT_PLUGINS', 'HERMES_OPTIONAL_SKILLS',
        'HERMES_GEMINI_CLIENT_ID', 'HERMES_INFERENCE_PROVIDER',
        'HERMES_OAUTH_TRACE', 'HERMES_BUDGET_MODE', 'HERMES_WORKDIR',
        'HERMES_GATEWAY_TOKEN', 'HERMES_LOCAL_STT_COMMAND', 'HERMES_LOCAL_STT_LANGUAGE',
        'HERMES_FORCE_FILE_SYNC', 'HERMES_STREAMING_ENABLED',
    ]:
        new = new.replace(env, env.replace('HERMES_', 'AATOS_'))

    # === RUNTIME MARKERS (generated strings) ===
    new = re.sub(r'\bHERMES_STDIN_\b', 'AATOS_STDIN_', new)
    new = re.sub(r'\bHERMES_EOF_\b', 'AATOS_EOF_', new)
    new = re.sub(r'\bHERMES_PERSIST_EOF\b', 'AATOS_PERSIST_EOF', new)
    new = re.sub(r'\b__HERMES_CWD_\b', '__AATOS_CWD_', new)
    new = re.sub(r'\b__hermes_ec\b', '__aatos_ec', new)
    new = re.sub(r'\b_hermes_now\b', '_aatos_now', new)
    new = re.sub(r'\b_hermes_root\b', '_aatos_root', new)
    new = re.sub(r'\bhermes_bg_\b', 'aatos_bg_', new)
    new = re.sub(r'\bhermes_rpc_\b', 'aatos_rpc_', new)
    new = re.sub(r'\bhermes_sandbox_\b', 'aatos_sandbox_', new)
    new = re.sub(r'\.hermes_test_\b', '.aatos_test_', new)
    new = re.sub(r'_hermes_injection_test\b', '_aatos_injection_test', new)
    new = re.sub(r'_hermes_upload\.b64\b', '_aatos_upload.b64', new)
    new = re.sub(r'_KIND_TO_HERMES\b', '_KIND_TO_AATOS', new)
    new = re.sub(r'_HERMES_OAUTH_FILE\b', '_AATOS_OAUTH_FILE', new)
    new = re.sub(r'_HERMES_MD_NAMES\b', '_AATOS_MD_NAMES', new)
    new = re.sub(r'_HERMES_ENV_PATH\b', '_AATOS_ENV_PATH', new)
    new = re.sub(r'_HERMES_SUBCOMMANDS\b', '_AATOS_SUBCOMMANDS', new)
    new = re.sub(r'_hermes_profiles\b', '_aatos_profiles', new)
    new = re.sub(r'_hermes_completion\b', '_aatos_completion', new)
    new = re.sub(r'\bhermes_action\b', 'aatos_action', new)

    # === SHELL SCRIPT NAMES ===
    new = re.sub(r'\bget_hermes_command_path\b', 'get_aatos_command_path', new)
    new = re.sub(r'\bopenclaw_to_hermes\.py\b', 'openclaw_to_aatos.py', new)
    new = re.sub(r'\bopenclaw_to_hermes\b', 'openclaw_to_aatos', new)
    new = re.sub(r'\bsetup-hermes\.sh\b', 'setup-aatos.sh', new)

    # === CamelCase standalone (must come after compound names) ===
    new = re.sub(r'\bHermes(?=[A-Z])\b', 'Aatos', new)

    # === lowercase standalone (must come after module/func names) ===
    new = re.sub(r'\bhermes(?![a-z_])', 'aatos', new)

    # === ALL-CAPS standalone (must come after specific env vars) ===
    new = re.sub(r'\bHERMES\b', 'AATOS', new)

    if new != content:
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(new)
        return True
    return False

count = 0
for dirpath, _, filenames in os.walk(root):
    for filename in filenames:
        if replace_in_file(os.path.join(dirpath, filename)):
            count += 1
print(f"Rebranded {count} files")
```

## Step 5: Commit & Push

```bash
cd /root/aatos-agent
git add -A
git commit -m "sync + rebrand: $(date -u +%Y%m%d-%H%M%S) — merge hermes-agent latest + full hermes->aatos rebrand"
git push origin main
```

## Verification

```bash
cd /root/aatos-agent
echo "Python hermes refs:" && grep -rn "hermes\|Hermes\|HERMES" --include="*.py" . 2>/dev/null | grep -v "aatos\|Aatos\|AATOS\|DeepHermes\|NousHermes\|Hermes-" | wc -l
echo "Other files hermes refs:" && grep -rn "hermes\|Hermes\|HERMES" --include="*.sh" --include="*.md" --include="*.txt" --include="*.yaml" --include="*.yml" --include="*.json" --include="Dockerfile" --include="*.nix" . 2>/dev/null | grep -v "aatos\|Aatos\|AATOS\|DeepHermes\|NousHermes\|Hermes-\|PAL_HERMES" | wc -l
echo "Should both be 0"
```

## Pattern Order Rules (CRITICAL)

1. Compound class names FIRST (`HermesAgentBaseEnv` before `Hermes`)
2. Module names before lowercase (`hermes_cli` before `hermes`)
3. Specific env vars before generic (`HERMES_HOME` before `HERMES`)
4. Runtime markers next (`HERMES_STDIN_`, `HERMES_EOF_`)
5. Shell script names
6. CamelCase standalone next
7. lowercase catchall LAST
8. ALL-CAPS standalone LAST of all

## Notes

- **Working dir is `/root/aatos-agent`** — NOT `/root/hermes-agent`
- hermes-agent is never written to; it is only read from
- Tests that reference runtime strings (`HERMES_STDIN_*`, `.hermes_test_*`, `_hermes_injection_test`) ARE rebranded — they test the rebranded system's behavior
- Model names (`DeepHermes-3`, `FP16_Hermes_4.5`) and palette `PAL_HERMES` are NOT rebranded (third-party identifiers)
- The old `hermes-agent` directory is a read-only mirror; all work happens in `/root/aatos-agent`
## Quick Commands
- `skill-load aatos-agent-sync` — Load this skill
