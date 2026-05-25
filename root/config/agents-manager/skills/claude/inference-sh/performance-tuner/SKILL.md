---
name: performance-tuner
description: Skill: performance-tuner
---

# Skill: performance-tuner

**Category:** inference-sh
**Version:** 1.0.0
**Author:** Hermes (Root Agent)
**Date:** 2026-03-31

## Description

Automatically tunes inference server performance based on hardware capacity, model requirements, and workload patterns. Optimizes concurrent pods, batch sizes, context lengths, and memory allocation for self-hosted AI.

## Trigger Conditions

Use when:
- Deploying new inference server
- Performance is degraded
- Adding new model
- GPU utilization is low but latency is high
- Want to optimize for throughput vs latency
- Setting up auto-scaling thresholds

---

## Tuning Parameters

### Ollama Tuning

```bash
# Environment variables for Ollama

OLLAMA_NUM_PARALLEL=4          # Concurrent requests per model (default: 1)
OLLAMA_MAX_LOADED_MODELS=3     # Models in memory (default: 1)
OLLAMA_VRAM_GUARD=0.05         # Reserve 5% VRAM buffer

# Example: High throughput setup
docker run -d \
  --name ollama \
  -p 11434:11434 \
  -v ollama:/root/.ollama \
  -e OLLAMA_NUM_PARALLEL=4 \
  -e OLLAMA_MAX_LOADED_MODELS=3 \
  -e OLLAMA_VRAM_GUARD=0.05 \
  --gpus all \
  ollama/ollama
```

### vLLM Tuning

```bash
# Key vLLM parameters

# Memory and utilization
--gpu-memory-utilization 0.90    # Use 90% of VRAM
--max-model-len 32768             # Context length
--num-gpu-accelerators 1          # GPUs to use

# Performance
--tensor-parallel-size 1          # Multi-GPU tensor parallel
--pipeline-parallel-size 1        # Pipeline parallelism
--enforce-eager                   # No CUDA graph (for small models)
--enable-chunked-prefill          # Better memory handling

# Throughput
--max-num-batched-tokens 8192     # Batch size
--max-num-seqs 256                # Max sequences in batch

# Example: Optimized for throughput
docker run -d \
  --name vllm \
  -p 8000:8000 \
  --gpus all \
  -v ~/.cache/huggingface:/root/.cache/huggingface \
  vllm/vllm-openai:latest \
  --model meta-llama/Llama-3.2-3B-Instruct \
  --gpu-memory-utilization 0.90 \
  --max-model-len 32768 \
  --enable-chunked-prefill \
  --max-num-batched-tokens 8192
```

---

## Auto-Tuning Scripts

### Hardware Detection

```bash
#!/bin/bash
# detect-hardware.sh — Detect hardware capacity

echo "=== Hardware Detection ==="

# CPU
CPU_CORES=$(nproc)
CPU_MEM=$(free -h | awk '/^Mem:/ {print $2}')
echo "CPU Cores: $CPU_CORES"
echo "System RAM: $CPU_MEM"

# GPU
if command -v nvidia-smi &> /dev/null; then
  GPU_COUNT=$(nvidia-smi --list-gpus | wc -l)
  GPU_NAME=$(nvidia-smi --query-gpu=name --format=csv,noheader | head -1)
  GPU_MEM=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits | head -1 | tr -d ' MiB')
  echo "GPU Count: $GPU_COUNT"
  echo "GPU Name: $GPU_NAME"
  echo "GPU Memory: ${GPU_MEM}MB per GPU"
  
  # Compute capability
  COMPUTE=$(nvidia-smi --query-gpu=compute_cap --format=csv,noheader | head -1)
  echo "Compute Capability: $COMPUTE"
fi

# Storage
DISK_SPEED=$(hdparm -t /dev/sda 2>/dev/null | grep -oP '(\d+\.\d+) MB/sec' || echo "Unknown")
echo "Disk Speed: $DISK_SPEED"
```

### Model VRAM Calculator

```bash
#!/bin/bash
# model-vram-calc.sh — Calculate VRAM needed for model

MODEL=$1

# Approximate VRAM requirements (MiB)
declare -A MODEL_VRAM
MODEL_VRAM["llama3.2-3b"]=6000
MODEL_VRAM["llama3.2-7b"]=14000
MODEL_VRAM["llama3.2-70b"]=80000
MODEL_VRAM["llama3.2-8b"]=16000
MODEL_VRAM["mistral-7b"]=14000
MODEL_VRAM["mixtral-8x7b"]=48000
MODEL_VRAM["codellama-7b"]=14000
MODEL_VRAM["codellama-13b"]=26000
MODEL_VRAM["phi-3-mini"]=8000
MODEL_VRAM["gemma-2b"]=4000
MODEL_VRAM["gemma-7b"]=14000

VRAM=${MODEL_VRAM[$MODEL]:-14000}
CONTEXT_OVERHEAD=$((VRAM / 4))  # ~25% overhead for context

echo "Model: $MODEL"
echo "Base VRAM: ${VRAM}MB"
echo "Context Overhead (32k context): ${CONTEXT_OVERHEAD}MB"
echo "Total Estimated VRAM: $((VRAM + CONTEXT_OVERHEAD))MB"
```

### Concurrent Pod Calculator

```bash
#!/bin/bash
# calc-concurrent-pods.sh — Calculate optimal concurrent pods

# Get hardware
GPU_MEM_TOTAL=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits | head -1 | tr -d ' MiB')
GPU_COUNT=$(nvidia-smi --list-gpus | wc -l)
TOTAL_MEM=$((GPU_MEM_TOTAL * GPU_COUNT))

# Get model (default to llama3.2-7b)
MODEL=${1:-"llama3.2-7b"}

# VRAM per model (see model-vram-calc.sh)
declare -A MODEL_VRAM
MODEL_VRAM["llama3.2-3b"]=6000
MODEL_VRAM["llama3.2-7b"]=14000
MODEL_VRAM["llama3.2-70b"]=80000
MODEL_VRAM["mistral-7b"]=14000
MODEL_VRAM["mixtral-8x7b"]=48000

VRAM_PER_POD=${MODEL_VRAM[$MODEL]:-14000}

# Calculate with headroom
USABLE_MEM=$((TOTAL_MEM * 85 / 100))  # 15% headroom
MAX_PODS=$((USABLE_MEM / VRAM_PER_POD))

echo "=== Concurrent Pod Calculation ==="
echo "Total VRAM: ${TOTAL_MEM}MB"
echo "Usable VRAM (85%): ${USABLE_MEM}MB"
echo "Model: $MODEL"
echo "VRAM per Pod: ${VRAM_PER_POD}MB"
echo ""
echo "Max Concurrent Pods: $MAX_PODS"
echo "Recommended Pods: $((MAX_PODS - 1))"
echo ""
echo "Recommended Ollama config:"
echo "  OLLAMA_NUM_PARALLEL=$((MAX_PODS > 4 ? 4 : MAX_PODS))"
echo "  OLLAMA_MAX_LOADED_MODELS=$((MAX_PODS - 1))"
```

---

## vLLM Optimization

### Batch Size Tuning

```bash
#!/bin/bash
# tune-vllm-batch.sh — Auto-tune vLLM batch parameters

# Detect GPU
GPU_MEM=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits | head -1 | tr -d ' MiB')

# Calculate optimal batch params
if [ "$GPU_MEM" -gt 80000 ]; then
  # High-end GPU (A100, H100)
  MAX_BATCHED=16384
  MAX_SEQS=512
  MODEL_LEN=65536
elif [ "$GPU_MEM" -gt 30000 ]; then
  # Mid-range (V100, RTX 6000)
  MAX_BATCHED=8192
  MAX_SEQS=256
  MODEL_LEN=32768
else
  # Entry-level (RTX 4090, 3090)
  MAX_BATCHED=4096
  MAX_SEQS=128
  MODEL_LEN=16384
fi

echo "Recommended vLLM parameters:"
echo "  --max-num-batched-tokens $MAX_BATCHED"
echo "  --max-num-seqs $MAX_SEQS"
echo "  --max-model-len $MODEL_LEN"
```

### Context Length Tuning

```bash
#!/bin/bash
# tune-context.sh — Tune context length based on VRAM

GPU_MEM=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits | head -1 | tr -d ' MiB')

if [ "$GPU_MEM" -gt 80000 ]; then
  echo "Context Length: 131072 (128k)"
  echo "Recommended for: 70B models"
elif [ "$GPU_MEM" -gt 40000 ]; then
  echo "Context Length: 65536 (64k)"
  echo "Recommended for: 13B-34B models"
elif [ "$GPU_MEM" -gt 20000 ]; then
  echo "Context Length: 32768 (32k)"
  echo "Recommended for: 7B-13B models"
else
  echo "Context Length: 16384 (16k)"
  echo "Recommended for: 3B-7B models"
fi
```

---

## Ollama Optimization

### Parallelism Tuning

```bash
#!/bin/bash
# tune-ollama.sh — Tune Ollama for hardware

CPU_CORES=$(nproc)
GPU_MEM=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits | head -1 | tr -d ' MiB')

# Calculate optimal parallelism
if [ "$GPU_MEM" -gt 40000 ]; then
  NUM_PARALLEL=4
  MAX_LOADED=3
elif [ "$GPU_MEM" -gt 20000 ]; then
  NUM_PARALLEL=2
  MAX_LOADED=2
else
  NUM_PARALLEL=1
  MAX_LOADED=1
fi

echo "Ollama environment variables:"
echo "  OLLAMA_NUM_PARALLEL=$NUM_PARALLEL"
echo "  OLLAMA_MAX_LOADED_MODELS=$MAX_LOADED"
echo ""
echo "Docker run example:"
echo "  docker run -d \\"
echo "    --name ollama \\"
echo "    -e OLLAMA_NUM_PARALLEL=$NUM_PARALLEL \\"
echo "    -e OLLAMA_MAX_LOADED_MODELS=$MAX_LOADED \\"
echo "    --gpus all \\"
echo "    ollama/ollama"
```

---

## Latency vs Throughput

### Low Latency Mode

```bash
# For chat/interactive use
docker run -d \
  --name vllm \
  -p 8000:8000 \
  --gpus all \
  vllm/vllm-openai:latest \
  --model $MODEL \
  --gpu-memory-utilization 0.85 \
  --max-model-len 8192 \
  --enforce-eager
```

### High Throughput Mode

```bash
# For batch processing
docker run -d \
  --name vllm \
  -p 8000:8000 \
  --gpus all \
  vllm/vllm-openai:latest \
  --model $MODEL \
  --gpu-memory-utilization 0.95 \
  --max-model-len 32768 \
  --enable-chunked-prefill \
  --max-num-batched-tokens 16384
```

### Balanced Mode

```bash
# General purpose
docker run -d \
  --name vllm \
  -p 8000:8000 \
  --gpus all \
  vllm/vllm-openai:latest \
  --model $MODEL \
  --gpu-memory-utilization 0.90 \
  --max-model-len 16384 \
  --enable-chunked-prefill
```

---

## Workload-Based Tuning

### Detect Workload Pattern

```bash
#!/bin/bash
# detect-workload.sh — Detect if workload is latency-sensitive or throughput-sensitive

# Check recent request patterns
# (Integrate with your inference server logs)

LATENCY_SENSITIVE=0
THROUGHPUT_SENSITIVE=0

# If average request rate > threshold and individual latency not critical
if [ "$REQUEST_RATE" -gt 100 ] && [ "$AVG_LATENCY" -lt 5000 ]; then
  THROUGHPUT_SENSITIVE=1
fi

# If interactive usage (short requests, low rate, low latency needed)
if [ "$AVG_TOKENS" -lt 1000 ] && [ "$REQUEST_RATE" -lt 50 ]; then
  LATENCY_SENSITIVE=1
fi

if [ "$LATENCY_SENSITIVE" -eq 1 ]; then
  echo "MODE=latency"
elif [ "$THROUGHPUT_SENSITIVE" -eq 1 ]; then
  echo "MODE=throughput"
else
  echo "MODE=balanced"
fi
```

---

## Skill Commands

| Command | Description |
|---------|-------------|
| `tune hardware-detect` | Detect hardware capacity |
| `tune model-vram <model>` | Calculate VRAM for model |
| `tune concurrent-pods <model>` | Calculate concurrent pods |
| `tune vllm-batch` | Auto-tune vLLM batch params |
| `tune vllm-context` | Tune context length |
| `tune ollama` | Tune Ollama parallelism |
| `tune workload-detect` | Detect workload pattern |
| `tune apply-latency` | Apply low-latency config |
| `tune apply-throughput` | Apply high-throughput config |
| `tune apply-balanced` | Apply balanced config |
| `tune status` | Show current tuning settings |

---

## Files

- `scripts/hardware-detect.sh` — Detect hardware
- `scripts/model-vram-calc.sh` — Calculate model VRAM
- `scripts/calc-concurrent-pods.sh` — Calculate pods
- `scripts/tune-vllm-batch.sh` — Tune vLLM batch
- `scripts/tune-context.sh` — Tune context length
- `scripts/tune-ollama.sh` — Tune Ollama
- `scripts/detect-workload.sh` — Detect workload pattern
## Quick Commands
- `skill-load performance-tuner` — Load this skill
