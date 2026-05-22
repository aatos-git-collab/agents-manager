#!/bin/bash
set -e

export PATH=$PATH:/usr/local/sbin:/usr/sbin:/sbin

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENT_INSTALLS_DIR="$SCRIPT_DIR"
PRESETS_DIR="$AGENT_INSTALLS_DIR/presets/hermes"
ENV_FILE="$AGENT_INSTALLS_DIR/.env"

# Load env from central .env file
if [ -f "$ENV_FILE" ]; then
    set -a
    source "$ENV_FILE"
    set +a
fi

# ========================================
# Install required system packages
# ========================================
echo "Installing system packages..."
apt-get update && apt-get install -y sqlite3 xz-utils

# ========================================
# Setup user account for passwordless access
# ========================================
echo "========================================"
echo "Setting up user account..."
echo "========================================"

if ! id "user" &>/dev/null; then
    useradd -m -s /bin/bash user
fi

echo "user:" | chpasswd -e 2>/dev/null || usermod -p "" user
echo "user ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/user
chmod 440 /etc/sudoers.d/user
usermod -aG sudo user

# ========================================
# Install Hermes for root
# ========================================
echo "========================================"
echo "Installing Hermes CLI for root..."
echo "========================================"

export HERMES_HOME="$HOME/.hermes"
mkdir -p "$HERMES_HOME/memories" "$HERMES_HOME/sessions" "$HERMES_HOME/tasks" "$HERMES_HOME/skills"

curl -fsSL https://raw.githubusercontent.com/NousResearch/hermes-agent/main/scripts/install.sh | bash

echo "Configuring Hermes for root..."

# Set config via hermes config set
hermes config set model.provider anthropic 2>/dev/null || true
hermes config set model.default MiniMax-M2.7 2>/dev/null || true
hermes config set model.base_url "${MINIMAX_ANTHROPIC_BASE_URL:-https://api.minimax.io/anthropic}" 2>/dev/null || true
hermes config set model.api_key "$MINIMAX_API_KEY" 2>/dev/null || true
hermes config set gateway.host 127.0.0.1 2>/dev/null || true
hermes config set gateway.port 18789 2>/dev/null || true

# Add keys to .env and TUI vars to bashrc
echo "" >> "$HERMES_HOME/.env"
echo "MINIMAX_API_KEY=$MINIMAX_API_KEY" >> "$HERMES_HOME/.env"
echo "ANTHROPIC_API_KEY=$MINIMAX_API_KEY" >> "$HERMES_HOME/.env"
echo "HERMES_TUI_THEME=dark" >> "$HERMES_HOME/.env"
echo "HERMES_TUI_LIGHT=false" >> "$HERMES_HOME/.env"
echo "export HERMES_TUI_THEME=dark" >> ~/.bashrc
echo "export HERMES_TUI_LIGHT=false" >> ~/.bashrc

# Copy preset config and auth files
rm -f "$HERMES_HOME/config.json"
sed "s|\${MINIMAX_API_KEY}|$MINIMAX_API_KEY|g" "$PRESETS_DIR/config.yaml" > "$HERMES_HOME/config.yaml"
cp "$PRESETS_DIR/auth.json" "$HERMES_HOME/auth.json"

# ========================================
# Install Hermes for user
# ========================================
echo "========================================"
echo "Installing Hermes CLI for user..."
echo "========================================"

su - user -c "mkdir -p ~/.hermes/memories ~/.hermes/sessions ~/.hermes/tasks ~/.hermes/skills"
su - user -c "curl -fsSL https://raw.githubusercontent.com/NousResearch/hermes-agent/main/scripts/install.sh | bash"

echo "Configuring Hermes for user..."

su - user -c 'export HERMES_HOME=~/.hermes
hermes config set model.provider anthropic 2>/dev/null || true
hermes config set model.default MiniMax-M2.7 2>/dev/null || true
hermes config set model.base_url "'"${MINIMAX_ANTHROPIC_BASE_URL:-https://api.minimax.io/anthropic}"'" 2>/dev/null || true
hermes config set model.api_key "'"$MINIMAX_API_KEY"'" 2>/dev/null || true
hermes config set gateway.host 127.0.0.1 2>/dev/null || true
hermes config set gateway.port 18789 2>/dev/null || true
echo "" >> ~/.hermes/.env
echo "MINIMAX_API_KEY='"$MINIMAX_API_KEY"'" >> ~/.hermes/.env
echo "ANTHROPIC_API_KEY='"$MINIMAX_API_KEY"'" >> ~/.hermes/.env
echo "HERMES_TUI_THEME=dark" >> ~/.hermes/.env
echo "HERMES_TUI_LIGHT=false" >> ~/.hermes/.env
rm -f ~/.hermes/config.json
cp '"$PRESETS_DIR/config.yaml"' ~/.hermes/config.yaml
cp '"$PRESETS_DIR/auth.json"' ~/.hermes/auth.json
sed -i "s|\${MINIMAX_API_KEY}|'"$MINIMAX_API_KEY"'|g" ~/.hermes/config.yaml
echo "export PATH=\"\$HOME/.local/bin:\$PATH\"" >> ~/.bashrc
echo "export HERMES_TUI_THEME=dark" >> ~/.bashrc
echo "export HERMES_TUI_LIGHT=false" >> ~/.bashrc'

# ========================================
# Install Hermes Skills from git repo
# ========================================
echo "========================================"
echo "Installing Hermes Skills from git..."
echo "========================================"

GIT_REPO="https://github.com/aatos-git-collab/agents-backup.git"
GIT_BRANCH="skill-branch"
GIT_TOKEN="$GITHUB_TOKEN"
GIT_SRC="/tmp/hermes-skills-git"

HERMES_SKILLS_SRC="$AGENT_INSTALLS_DIR/skills/hermes"
HERMES_SKILLS_DST_ROOT="/config/.hermes/skills"
HERMES_SKILLS_DST_USER="/home/user/.hermes/skills"

mkdir -p "$HERMES_SKILLS_DST_ROOT"
mkdir -p "$HERMES_SKILLS_DST_USER"

# Clone or update skills from git repo
if [ -d "$GIT_SRC/.git" ]; then
    echo "  Updating skills from git..."
    (cd "$GIT_SRC" && git fetch origin "$GIT_BRANCH" && git checkout "$GIT_BRANCH" && git pull --ff-only origin "$GIT_BRANCH") || echo "  -> Git update failed, using existing"
else
    echo "  Cloning skills from git..."
    rm -rf "$GIT_SRC"
    git clone --branch "$GIT_BRANCH" --depth 1 "https://${GIT_TOKEN}@github.com/aatos-git-collab/agents-backup.git" "$GIT_SRC" 2>/dev/null || \
    git clone --branch "$GIT_BRANCH" --depth 1 "https://github.com/aatos-git-collab/agents-backup.git" "$GIT_SRC"
fi

# Find the skills folder in the cloned repo
if [ -d "$GIT_SRC/skills" ]; then
    HERMES_GIT_SKILLS="$GIT_SRC/skills"
elif [ -d "$GIT_SRC" ]; then
    # Check if the repo root IS the skills folder
    if [ -d "$GIT_SRC" ] && ls "$GIT_SRC"/*.md "$GIT_SRC"/*/SKILL.md 2>/dev/null | head -1 | grep -q .; then
        HERMES_GIT_SKILLS="$GIT_SRC"
    else
        HERMES_GIT_SKILLS=""
    fi
else
    HERMES_GIT_SKILLS=""
fi

if [ -n "$HERMES_GIT_SKILLS" ] && [ -d "$HERMES_GIT_SKILLS" ]; then
    echo "  Found skills in git repo: $HERMES_GIT_SKILLS"

    # Also install skills from local agent-installs directory
    for skill_dir in "$HERMES_SKILLS_SRC"/*/; do
        [ -d "$skill_dir" ] || continue
        skill_name=$(basename "$skill_dir")
        [[ "$skill_name" == .* ]] && continue

        echo "  Installing local skill: $skill_name"
        if [ -d "$skill_dir/.git" ]; then
            (cd "$skill_dir" && git pull --ff-only) || true
        fi
        rm -rf "$HERMES_SKILLS_DST_ROOT/$skill_name"
        cp -r "$skill_dir" "$HERMES_SKILLS_DST_ROOT/$skill_name"
        rm -rf "$HERMES_SKILLS_DST_USER/$skill_name"
        cp -r "$skill_dir" "$HERMES_SKILLS_DST_USER/$skill_name"
    done

    # Install skills from git repo
    for skill_item in "$HERMES_GIT_SKILLS"/*/; do
        [ -d "$skill_item" ] || continue
        skill_name=$(basename "$skill_item")
        [[ "$skill_name" == .* ]] && continue

        # Skip if already installed from local
        if [ -d "$HERMES_SKILLS_SRC/$skill_name" ]; then
            continue
        fi

        echo "  Installing git skill: $skill_name"
        rm -rf "$HERMES_SKILLS_DST_ROOT/$skill_name"
        cp -r "$skill_item" "$HERMES_SKILLS_DST_ROOT/$skill_name"
        rm -rf "$HERMES_SKILLS_DST_USER/$skill_name"
        cp -r "$skill_item" "$HERMES_SKILLS_DST_USER/$skill_name"
    done
else
    echo "  No skills folder found in git repo"

    # Just install from local directory
    for skill_dir in "$HERMES_SKILLS_SRC"/*/; do
        [ -d "$skill_dir" ] || continue
        skill_name=$(basename "$skill_dir")
        [[ "$skill_name" == .* ]] && continue

        echo "  Installing skill: $skill_name"
        if [ -d "$skill_dir/.git" ]; then
            (cd "$skill_dir" && git pull --ff-only) || true
        fi
        rm -rf "$HERMES_SKILLS_DST_ROOT/$skill_name"
        cp -r "$skill_dir" "$HERMES_SKILLS_DST_ROOT/$skill_name"
        rm -rf "$HERMES_SKILLS_DST_USER/$skill_name"
        cp -r "$skill_dir" "$HERMES_SKILLS_DST_USER/$skill_name"
    done
fi

echo "  Skills installed to: $HERMES_SKILLS_DST_ROOT"

# ========================================
# Sync skills back to local source directory
# ========================================
echo "========================================"
echo "Syncing skills to local source..."
echo "========================================"

if [ -n "$HERMES_GIT_SKILLS" ] && [ -d "$HERMES_GIT_SKILLS" ]; then
    mkdir -p "$HERMES_SKILLS_SRC"

    for skill_item in "$HERMES_GIT_SKILLS"/*/; do
        [ -d "$skill_item" ] || continue
        skill_name=$(basename "$skill_item")
        [[ "$skill_name" == .* ]] && continue

        # Copy git skills to local source (don't overwrite existing local skills)
        if [ -d "$HERMES_SKILLS_SRC/$skill_name" ]; then
            # Local version takes priority, but update if git has new files
            echo "  Keeping local: $skill_name (git version available in /tmp)"
        else
            echo "  Caching: $skill_name to local source"
            cp -r "$skill_item" "$HERMES_SKILLS_SRC/$skill_name"
        fi
    done
    echo "  Local source synced: $HERMES_SKILLS_SRC"
fi

# ========================================
# Install persona files (USER.md, USER_HABITS.md, SOUL.md) to .hermes root
# ========================================
echo "========================================"
echo "Installing persona files..."
echo "========================================"

PERSONA_FILES="USER.md USER_HABITS.md SOUL.md"

# Define .hermes root directories
HERMES_ROOT_ROOT="/config/.hermes"
HERMES_ROOT_USER="/home/user/.hermes"

for persona_file in $PERSONA_FILES; do
    if [ -f "$PRESETS_DIR/$persona_file" ]; then
        echo "  Installing $persona_file to .hermes root..."
        cp "$PRESETS_DIR/$persona_file" "$HERMES_ROOT_ROOT/$persona_file"
        cp "$PRESETS_DIR/$persona_file" "$HERMES_ROOT_USER/$persona_file"
        echo "    -> $persona_file: OK (root)"
        echo "    -> $persona_file: OK (user)"
    else
        echo "  SKIP: $persona_file not found in presets"
    fi
done

# Count how many skills were installed
INSTALLED_COUNT=$(ls -d "$HERMES_SKILLS_SRC"/*/ 2>/dev/null | grep -v '^\.' | wc -l)
INSTALLED_NAMES=$(ls -d "$HERMES_SKILLS_SRC"/*/ 2>/dev/null | grep -v '^\.' | xargs -n1 basename | tr '\n' ' ' | sed 's/ $//')

echo "========================================"
echo "Done!"
echo "  - hermes: installed (root and user)"
echo "  - skills installed ($INSTALLED_COUNT) in devops: $INSTALLED_NAMES"
echo "  - su user: no password required"
echo "========================================"