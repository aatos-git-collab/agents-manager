---
name: model-manager
description: Skill: model-manager
---

# Skill: model-manager

**Category:** inference-sh
**Version:** 1.0.0
**Author:** Hermes (Root Agent)
**Date:** 2026-03-31

## Description

Manages AI models for self-hosted inference servers. Handles downloading, organizing, switching, and removing models from Ollama, vLLM, LocalAI, and HuggingFace. Works with GGUF, GGML, and Safetensors formats.

## Trigger Conditions

Use when:
- User wants to download a new model
- User wants to list available models
- User wants to switch default model
- User wants to remove unused models to free space
- Setting up model catalog for hermes-core

---

## Model Sources

### Ollama Models

```bash
# Popular models
ollama pull llama3.2          # Latest Meta Llama
ollama pull llama3.2:3b       # Smaller variant
ollama pull mistral            # Mistral AI
ollama pull mixtral            # Mixtral 8x7B
ollama pull codellama          # Code-specialized
ollama pull phi                # Microsoft Phi-3
ollama pull neural-chat        # Intel Neural Chat
ollama pull wizardcoder        # Code generation

# Embedding models
ollama pull nomic-embed-text   # Text embeddings
```

### HuggingFace Models (for vLLM/LocalAI)

```bash
# Install huggingface-hub
pip install huggingface-hub

# Download model
huggingface-cli download \
  meta-llama/Llama-3.2-3B-Instruct \
  --local-dir /models/llama3.2-3b

# Or via Python
python3 << 'EOF'
from huggingface_hub import snapshot_download
snapshot_download(
    repo_id="meta-llama/Llama-3.2-3B-Instruct",
    local_dir="/models/llama3.2-3b"
)
EOF
```

---

## Model Management Commands

### List Models

```bash
#!/bin/bash
# list-all-models.sh

echo "=== OLLAMA ==="
ollama list 2>/dev/null

echo ""
echo "=== VLLM ==="
curl -s http://localhost:8000/v1/models 2>/dev/null | \
  jq -r '.data[].id' 2>/dev/null || echo "vLLM not running"

echo ""
echo "=== LOCALAI ==="
curl -s http://localhost:8080/v1/models 2>/dev/null | \
  jq -r '.data[].id' 2>/dev/null || echo "LocalAI not running"

echo ""
echo "=== HUGGINGFACE (downloaded) ==="
ls -la /models/ 2>/dev/null || echo "No models directory"
```

### Download Model

```bash
#!/bin/bash
# download-model.sh <source> <model_name> [destination]
# source: ollama, hf, gguf
# examples:
#   ./download-model.sh ollama llama3.2
#   ./download-model.sh hf meta-llama/Llama-3.2-3B-Instruct /models

SOURCE=$1
MODEL=$2
DEST=${3:-"/models/$MODEL"}

case $SOURCE in
  ollama)
    ollama pull "$MODEL"
    ;;
  hf)
    huggingface-cli download "$MODEL" --local-dir "$DEST"
    ;;
  gguf)
    # Download GGUF from HuggingFace
    python3 -c "
from huggingface_hub import hf_hub_download
path = hf_hub_download(repo_id='$MODEL', filename='*.gguf', local_dir='$DEST')
print(f'Downloaded: {path}')
"
    ;;
esac
```

### Remove Model

```bash
#!/bin/bash
# remove-model.sh <provider> <model_name>

PROVIDER=$1
MODEL=$2

case $PROVIDER in
  ollama)
    ollama rm "$MODEL"
    ;;
  vllm|hf|localai)
    rm -rf "/models/$MODEL"
    ;;
esac

echo "Removed $MODEL from $PROVIDER"
```

### Switch Default Model

```bash
#!/bin/bash
# set-default-model.sh <provider> <model_name>

PROVIDER=$1
MODEL=$2

# Update hermes-core config
yq e ".providers.$PROVIDER.default_model = \"$MODEL\"" -i /etc/hermes-core.yaml

echo "Default model set to $MODEL for $PROVIDER"
```

---

## Model Catalog

### Model Info JSON

```json
{
  "models": [
    {
      "name": "llama3.2",
      "provider": "ollama",
      "size": "7B",
      "context_length": 32768,
      "quantization": "Q4_K_M",
      "vram_required": "8GB",
      "use_cases": ["general", "coding", "reasoning"]
    },
    {
      "name": "mistral",
      "provider": "ollama", 
      "size": "7B",
      "context_length": 8192,
      "quantization": "Q4_K_M",
      "vram_required": "6GB",
      "use_cases": ["general", "chat"]
    },
    {
      "name": "mixtral",
      "provider": "ollama",
      "size": "8x7B",
      "context_length": 32768,
      "quantization": "Q4_K_M",
      "vram_required": "24GB",
      "use_cases": ["general", "coding", "reasoning", "multilingual"]
    },
    {
      "name": "codellama",
      "provider": "ollama",
      "size": "7B",
      "context_length": 16384,
      "quantization": "Q4_K_M",
      "vram_required": "6GB",
      "use_cases": ["code_generation", "code_completion"]
    },
    {
      "name": "nomic-embed-text",
      "provider": "ollama",
      "size": "137M",
      "context_length": 8192,
      "quantization": "F16",
      "vram_required": "1GB",
      "use_cases": ["embeddings", "semantic_search"]
    }
  ]
}
```

---

## Disk Space Management

```bash
#!/bin/bash
# check-model-sizes.sh

echo "=== OLLAMA Model Sizes ==="
du -sh ~/.ollama/models/ 2>/dev/null || echo "No Ollama models"

echo ""
echo "=== /models Directory ==="
du -sh /models/ 2>/dev/null || echo "No /models directory"

echo ""
echo "=== Available Disk Space ==="
df -h /models ~/.ollama 2>/dev/null

echo ""
echo "=== Largest Models ==="
du -sh ~/.ollama/models/blobs/* 2>/dev/null | sort -rh | head -10
```

---

## Skill Commands

| Command | Description |
|---------|-------------|
| `models list` | List all models across providers |
| `models pull <model>` | Download model |
| `models remove <model>` | Remove model |
| `models info <model>` | Show model details |
| `models set-default <provider> <model>` | Set default model |
| `models catalog` | Show model catalog JSON |
| `models sizes` | Show disk usage by model |
| `models search <query>` | Search available models |
## Quick Commands
- `skill-load model-manager` — Load this skill
