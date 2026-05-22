---
name: self-hosted-ai-manager
description: Skill: self-hosted-ai-manager
---

# Skill: self-hosted-ai-manager

**Category:** inference-sh
**Version:** 1.0.0
**Author:** Hermes (Root Agent)
**Date:** 2026-03-31

## Description

Manages self-hosted AI inference infrastructure — Ollama, vLLM, LocalAI, text-generation-webui, and other inference servers. Handles deployment, model management, scaling, monitoring, and performance tuning.

## Capabilities

- Deploy and configure inference servers (Ollama, vLLM, LocalAI)
- Manage models (download, list, remove, switch)
- Monitor GPU/CPU usage and memory
- Auto-scale concurrent pods based on hardware capacity
- Health checks and automatic restart on failure
- Integrate with hermes-core as LLM provider

## Trigger Conditions

Use this skill when:
- User asks to set up or manage self-hosted AI
- User wants to add/remove/switch models
- User wants to monitor AI server performance
- User wants to tune inference server settings
- Setting up hermes-core provider configuration

## Prerequisites

- Docker or Podman installed
- NVIDIA GPU with CUDA (for GPU inference)
- SSH access to server (if remote)
- Sufficient disk space for models

---

## Ollama Management

### Deploy Ollama Server

```bash
# Run Ollama server
docker run -d \
  --name ollama \
  -p 11434:11434 \
  -v ollama:/root/.ollama \
  --restart unless-stopped \
  ollama/ollama

# Or with GPU support
docker run -d \
  --name ollama \
  -p 11434:11434 \
  -v ollama:/root/.ollama \
  --gpus all \
  --restart unless-stopped \
  ollama/ollama
```

### Common Ollama Commands

```bash
# List installed models
ollama list

# Pull a model
ollama pull llama3.2
ollama pull mistral
ollama pull codellama

# Remove a model
ollama rm llama3.2

# Copy a model (for fine-tuned versions)
ollama cp llama3.2 my-llama3.2-custom

# Show model info
ollama show llama3.2

# Run interactively
ollama run llama3.2 "Explain quantum computing"

# Run with specific parameters
ollama run llama3.2 --temp 0.7 --top-p 0.9 --num_ctx 4096 "Your prompt"
```

### Ollama REST API

```bash
# Generate completion
curl http://localhost:11434/api/generate -d '{
  "model": "llama3.2",
  "prompt": "Hello world",
  "stream": false
}'

# Chat completion
curl http://localhost:11434/api/chat -d '{
  "model": "llama3.2",
  "messages": [
    {"role": "user", "content": "Hello!"}
  ]
}'

# Check server status
curl http://localhost:11434/api/tags
```

---

## vLLM Management

### Deploy vLLM Server

```bash
# vLLM with HuggingFace model
docker run -d \
  --name vllm \
  -p 8000:8000 \
  --gpus all \
  -v ~/.cache/huggingface:/root/.cache/huggingface \
  --restart unless-stopped \
  vllm/vllm-openai:latest \
  --model meta-llama/Llama-3.2-3B-Instruct \
  --gpu-memory-utilization 0.90 \
  --max-model-len 4096

# vLLM with custom model path
docker run -d \
  --name vllm \
  -p 8000:8000 \
  --gpus all \
  -v /path/to/models:/models \
  --restart unless-stopped \
  vllm/vllm-openai:latest \
  --model /models/my-custom-model \
  --gpu-memory-utilization 0.90
```

### vLLM API Usage

```bash
# OpenAI-compatible API
curl http://localhost:8000/v1/chat/completions -H "Content-Type: application/json" -d '{
  "model": "meta-llama/Llama-3.2-3B-Instruct",
  "messages": [{"role": "user", "content": "Hello!"}]
}'

# List models
curl http://localhost:8000/v1/models
```

---

## LocalAI Management

### Deploy LocalAI

```bash
# Deploy LocalAI
docker run -d \
  --name localai \
  -p 8080:8080 \
  -v $PWD/models:/models \
  -v $PWD/data:/data \
  --restart unless-stopped \
  quay.io/go-skynet/local-ai:latest

# LocalAI with GPU
docker run -d \
  --name localai \
  -p 8080:8080 \
  --gpus all \
  -v $PWD/models:/models \
  -v $PWD/data:/data \
  --restart unless-stopped \
  quay.io/go-skynet/local-ai:latest-gpu
```

### LocalAI API

```bash
# Chat completion
curl http://localhost:8080/v1/chat/completions -H "Content-Type: application/json" -d '{
  "model": "llama3.2",
  "messages": [{"role": "user", "content": "Hello!"}]
}'
```

---

## Model Management

### Model Download Script

```bash
#!/bin/bash
# download-model.sh — Download models from HuggingFace

MODEL=$1
DEST_DIR=${2:-"/models"}

mkdir -p "$DEST_DIR"

# For Ollama
if command -v ollama &> /dev/null; then
    ollama pull "$MODEL"
fi

# For vLLM/LocalAI (HuggingFace)
if command -v huggingface-cli &> /dev/null; then
    huggingface-cli download "$MODEL" --local-dir "$DEST_DIR/$MODEL"
fi
```

### List Available Models

```bash
#!/bin/bash
# list-models.sh — List all installed models

echo "=== Ollama Models ==="
ollama list 2>/dev/null || echo "Ollama not installed"

echo ""
echo "=== vLLM Models ==="
curl -s http://localhost:8000/v1/models 2>/dev/null | jq '.data[].id' || echo "vLLM not running"

echo ""
echo "=== LocalAI Models ==="
curl -s http://localhost:8080/v1/models 2>/dev/null | jq '.data[].id' || echo "LocalAI not running"
```

---

## GPU Monitoring

### GPU Status Script

```bash
#!/bin/bash
# gpu-status.sh — Check GPU usage

if command -v nvidia-smi &> /dev/null; then
    nvidia-smi --query-gpu=index,name,utilization.gpu,memory.used,memory.total,temperature.gpu --format=csv
else
    echo "NVIDIA GPU not detected"
fi
```

### Memory-Focused Monitoring

```bash
#!/bin/bash
# gpu-memory.sh — Check GPU memory usage

nvidia-smi --query-gpu=index,name,memory.used,memory.total,memory.free --format=csv,noheader,nounits
```

### Auto-Scaling Decision Script

```bash
#!/bin/bash
# should-scale.sh — Determine if we should scale inference pods

# Thresholds
MAX_GPU_MEM=${MAX_GPU_MEM:-90}
MAX_GPU_UTIL=${MAX_GPU_UTIL:-95}
MIN_IDLE=${MIN_IDLE:-10}

# Get GPU stats
GPU_MEM=$(nvidia-smi --query-gpu=memory.utilization --format=csv,noheader,nounits)
GPU_UTIL=$(nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits)
IDLE_PODS=$(echo "TODO: get idle pod count" | bc)

# Decision
if [ "$GPU_MEM" -gt "$MAX_GPU_MEM" ] || [ "$GPU_UTIL" -gt "$MAX_GPU_UTIL" ]; then
    echo "SCALE_UP"
elif [ "$IDLE_PODS" -gt "$MIN_IDLE" ]; then
    echo "SCALE_DOWN"
else
    echo "STABLE"
fi
```

---

## Performance Tuning

### Ollama Tuning

| Parameter | Default | Recommended | Use Case |
|-----------|---------|-------------|----------|
| `OLLAMA_NUM_PARALLEL` | 1 | 2-4 | Concurrent requests |
| `OLLAMA_MAX_LOADED_MODELS` | 1 | 2-3 | Multiple models in memory |
| `OLLAMA_VRAM_GUARD` | 0.1 | 0.05-0.15 | VRAM buffer |

### vLLM Tuning

| Parameter | Default | Recommended | Use Case |
|-----------|---------|-------------|----------|
| `--gpu-memory-utilization` | 0.9 | 0.85-0.95 | VRAM usage |
| `--max-model-len` | 4096 | 8192-32768 | Context length |
| `--tensor-parallel-size` | 1 | 2-8 | Multi-GPU |
| `--num-gpu-accelerators` | 1 | Auto-detect | GPU count |
| `--enforce-eager` | False | True for small models | Memory optimization |

### Concurrent Pod Scaling

```bash
#!/bin/bash
# auto-scale-inference.sh — Auto-scale inference containers

# Get hardware capacity
GPU_COUNT=$(nvidia-smi --list-gpus | wc -l)
TOTAL_VRAM=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits | awk '{sum+=$1} END {print sum}')
MODEL_VRAM=$1  # e.g., 8000 for 8GB model

# Calculate max concurrent pods
MAX_PODS=$((TOTAL_VRAM / MODEL_VRAM))
RECOMMENDED_PODS=$((MAX_PODS - 1))  # Keep 1 slot free

echo "GPU Count: $GPU_COUNT"
echo "Total VRAM: ${TOTAL_VRAM}MB"
echo "Model VRAM: ${MODEL_VRAM}MB"
echo "Max Pods: $MAX_PODS"
echo "Recommended Pods: $RECOMMENDED_PODS"

# Apply to docker-compose or k8s
if [ -f docker-compose.yml ]; then
    # Update replicas
    yq e ".services.ollama.deploy.replicas = $RECOMMENDED_PODS" -i docker-compose.yml
fi
```

---

## Integration with hermes-core

### Configure Ollama as Provider

In `hermes-core.yaml`:

```yaml
providers:
  ollama:
    name: "Ollama (Local)"
    base_url: "http://localhost:11434"
    api_key: "ollama"  # dummy for local
    default_model: "llama3.2"
    models:
      - name: "llama3.2"
        context_length: 32768
      - name: "mistral"
        context_length: 8192
      - name: "codellama"
        context_length: 16384
```

### Configure vLLM as Provider

```yaml
providers:
  vllm:
    name: "vLLM (Local)"
    base_url: "http://localhost:8000/v1"
    api_key: "EMPTY"  # vLLM doesn't require key
    default_model: "meta-llama/Llama-3.2-3B-Instruct"
    models:
      - name: "meta-llama/Llama-3.2-3B-Instruct"
        context_length: 32768
```

### Health Check Script

```bash
#!/bin/bash
# inference-health.sh — Check if inference server is healthy

ENDPOINT=${1:-"http://localhost:11434/api/tags"}
EXPECTED_MODEL=${2:-"llama3.2"}

response=$(curl -s -w "%{http_code}" "$ENDPOINT" -o /dev/null)

if [ "$response" = "200" ]; then
    echo "HEALTHY"
    exit 0
else
    echo "UNHEALTHY (HTTP $response)"
    exit 1
fi
```

---

## Troubleshooting

| Issue | Cause | Solution |
|-------|-------|----------|
| Ollama slow response | Too many parallel requests | Reduce `OLLAMA_NUM_PARALLEL` |
| vLLM OOM | Model too large for VRAM | Reduce `--gpu-memory-utilization` or use smaller model |
| Model not loading | Disk space | Free space, `ollama rm` unused models |
| GPU not detected | CUDA not installed | Install NVIDIA driver + CUDA toolkit |
| API timeout | Server overloaded | Scale up pods or reduce load |

---

## Skill Commands

| Command | Description |
|---------|-------------|
| `inference status` | Check all inference server status |
| `inference deploy ollama\|vllm\|localai` | Deploy inference server |
| `inference models list` | List installed models |
| `inference models pull <model>` | Download a model |
| `inference models remove <model>` | Remove a model |
| `inference gpu` | Show GPU usage |
| `inference scale <count>` | Scale inference pods |
| `inference tune <model>` | Auto-tune for model |
| `inference health` | Health check all servers |
| `inference config show` | Show current configuration |
| `inference provider set <name>` | Set default provider |

---

## Files

- `scripts/ollama-deploy.sh` — Deploy Ollama server
- `scripts/vllm-deploy.sh` — Deploy vLLM server
- `scripts/localai-deploy.sh` — Deploy LocalAI server
- `scripts/gpu-status.sh` — GPU monitoring
- `scripts/auto-scale.sh` — Auto-scale inference pods
- `scripts/model-download.sh` — Download models
- `scripts/health-check.sh` — Health check all servers
- `scripts/inference-status.sh` — Overall inference status
## Quick Commands
- `skill-load self-hosted-ai-manager` — Load this skill
