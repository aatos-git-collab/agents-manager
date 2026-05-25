---
name: gpu-monitor
description: Skill: gpu-monitor
---

# Skill: gpu-monitor

**Category:** inference-sh
**Version:** 1.0.0
**Author:** Hermes (Root Agent)
**Date:** 2026-03-31

## Description

Monitors NVIDIA GPU usage, memory, temperature, and utilization. Used by the auto-scaling system to determine when to spin up/down inference pods. Integrates with hermes-core pool manager.

## Trigger Conditions

Use when:
- Checking GPU status and availability
- Auto-scaling decision needs data
- Troubleshooting performance issues
- Planning capacity for new models
- Setting up inference server deployment

---

## GPU Status

### Basic GPU Info

```bash
# List all GPUs
nvidia-smi -L

# Full status
nvidia-smi

# Query specific fields
nvidia-smi --query-gpu=index,name,utilization.gpu,utilization.memory,memory.used,memory.total,temperature.gpu --format=csv
```

### Output Format

```
index,name,utilization.gpu [%],utilization.memory [%],memory.used [MiB],memory.total [MiB],temperature.gpu [°C]
0,Tesla V100-PCIE-32GB,45 %,12 %,14336 MiB,32510 MiB,42
1,Tesla V100-PCIE-32GB,90 %,85 %,27653 MiB,32510 MiB,65
```

---

## GPU Monitoring Scripts

### Real-time Monitor

```bash
#!/bin/bash
# gpu-watch.sh — Watch GPU usage in real-time

watch -n 1 'nvidia-smi --query-gpu=index,name,temperature.gpu,utilization.gpu,utilization.memory,memory.used,memory.total --format=csv,noheader,nounits'
```

### GPU Status JSON

```bash
#!/bin/bash
# gpu-status-json.sh — Output GPU status as JSON

nvidia-smi --query-gpu=index,name,utilization.gpu,utilization.memory,memory.used,memory.total,temperature.gpu,power.draw,power.limit \
  --format=csv,noheader \
  | awk -F', ' '
{
  gsub(/%/, "", $3)
  gsub(/%/, "", $4)
  gsub(/MiB/, "", $5)
  gsub(/MiB/, "", $6)
  gsub(/[ ]*MiB/, "", $5)
  gsub(/[ ]*MiB/, "", $6)
}
{
  printf "{\n"
  printf "  \"index\": %s,\n", $1
  printf "  \"name\": \"%s\",\n", $2
  printf "  \"gpu_util\": %s,\n", $3
  printf "  \"mem_util\": %s,\n", $4
  printf "  \"memory_used\": %s,\n", $5
  printf "  \"memory_total\": %s,\n", $6
  printf "  \"temperature\": %s,\n", $7
  printf "  \"power_draw\": %s,\n", $8
  printf "  \"power_limit\": %s\n", $9
  printf "}\n"
}' | jq -s '.'
```

### Summary Stats

```bash
#!/bin/bash
# gpu-summary.sh — Summary of all GPUs

GPUS=$(nvidia-smi --query-gpu=index,name,memory.total,memory.free,memory.used,utilization.gpu --format=csv,noheader,nounits)

TOTAL_MEM=0
FREE_MEM=0
USED_MEM=0
TOTAL_UTIL=0
GPU_COUNT=0

while IFS=, read -r index name total free used util; do
  TOTAL_MEM=$((TOTAL_MEM + total))
  FREE_MEM=$((FREE_MEM + free))
  USED_MEM=$((USED_MEM + used))
  TOTAL_UTIL=$((TOTAL_UTIL + util))
  GPU_COUNT=$((GPU_COUNT + 1))
done <<< "$GPUS"

AVG_UTIL=$((TOTAL_UTIL / GPU_COUNT))

echo "=== GPU Summary ==="
echo "GPUs: $GPU_COUNT"
echo "Total Memory: $((TOTAL_MEM / 1024))GB"
echo "Used Memory: $((USED_MEM / 1024))GB"
echo "Free Memory: $((FREE_MEM / 1024))GB"
echo "Average Utilization: ${AVG_UTIL}%"
```

---

## Auto-Scaling Integration

### Scaling Decision Script

```bash
#!/bin/bash
# gpu-decide-scale.sh — Decide scaling action based on GPU

# Thresholds (configurable)
CRITICAL_GPU=${CRITICAL_GPU:-90}      # Scale UP if GPU util > 90%
CRITICAL_MEM=${CRITICAL_MEM:-90}       # Scale UP if memory > 90%  
HIGH_GPU=${HIGH_GPU:-75}              # Consider scale if > 75%
LOW_GPU=${LOW_GPU:-20}                # Scale DOWN if < 20% for 5 min
LOW_UTIL_COUNT=${LOW_UTIL_COUNT:-3}    # Consecutive low readings

# Get current stats
STATS=$(nvidia-smi --query-gpu=utilization.gpu,utilization.memory --format=csv,noheader,nounits)
GPU_UTIL=$(echo "$STATS" | head -1 | awk -F',' '{gsub(/[ %]/, "", $1); print $1}')
MEM_UTIL=$(echo "$STATS" | head -1 | awk -F',' '{gsub(/[ %]/, "", $2); print $1}')

# Decision
if [ "$GPU_UTIL" -ge "$CRITICAL_GPU" ] || [ "$MEM_UTIL" -ge "$CRITICAL_MEM" ]; then
  echo "ACTION=SCALE_UP REASON=gpu_or_mem_critical GPU=${GPU_UTIL}% MEM=${MEM_UTIL}%"
  exit 0
elif [ "$GPU_UTIL" -lt "$LOW_GPU" ]; then
  echo "ACTION=SCALE_DOWN REASON=gpu_idle GPU=${GPU_UTIL}%"
  exit 0
else
  echo "ACTION=HOLD REASON=within_threshold GPU=${GPU_UTIL}% MEM=${MEM_UTIL}%"
  exit 0
fi
```

### Pool Capacity Calculator

```bash
#!/bin/bash
# gpu-pool-capacity.sh — Calculate max inference pods

# Model VRAM requirements (in MiB)
declare -A MODEL_VRAM
MODEL_VRAM["llama3.2-3b"]=6000
MODEL_VRAM["llama3.2-7b"]=14000
MODEL_VRAM["llama3.2-70b"]=48000
MODEL_VRAM["mistral-7b"]=14000
MODEL_VRAM["mixtral-8x7b"]=48000
MODEL_VRAM["codellama-7b"]=14000

# Get GPU memory
TOTAL_MEM=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits | head -1 | tr -d ' MiB')
GPU_COUNT=$(nvidia-smi --list-gpus | wc -l)

# Reserve 10% headroom
USABLE_MEM=$((TOTAL_MEM * 90 / 100))

# Default model
MODEL=${1:-"llama3.2-7b"}
VRAM_PER_POD=${MODEL_VRAM[$MODEL]:-14000}

MAX_PODS=$((USABLE_MEM / VRAM_PER_POD))
RECOMMENDED_PODS=$((MAX_PODS - 1))  # Keep 1 slot free

echo "GPU Count: $GPU_COUNT"
echo "Total VRAM: ${TOTAL_MEM}MB per GPU"
echo "Usable VRAM: ${USABLE_MEM}MB per GPU"
echo "Model: $MODEL (${VRAM_PER_POD}MB per pod)"
echo "Max Pods per GPU: $MAX_PODS"
echo "Recommended Pods per GPU: $RECOMMENDED_PODS"
echo "Total Recommended Pods: $((RECOMMENDED_PODS * GPU_COUNT))"
```

---

## Prometheus Integration

### GPU Exporter Metrics

```bash
#!/bin/bash
# gpu-prometheus-metrics.sh — Output for Prometheus node_exporter

nvidia-smi --query-gpu=index,name,utilization.gpu,utilization.memory,memory.used,memory.total,temperature.gpu,power.draw \
  --format=csv,noheader,nounits \
  | while IFS=, read -r index name gpu_util mem_util used total temp power; do
    cat << EOF
# HELP nvidia_gpu_utilization GPU utilization percentage
# TYPE nvidia_gpu_utilization gauge
nvidia_gpu_utilization{index="$index",name="$name"} $gpu_util

# HELP nvidia_memory_utilization Memory utilization percentage
# TYPE nvidia_memory_utilization gauge
nvidia_memory_utilization{index="$index",name="$name"} $mem_util

# HELP nvidia_memory_used_bytes Memory used in bytes
# TYPE nvidia_memory_used_bytes gauge
nvidia_memory_used_bytes{index="$index",name="$name"} $((used * 1024 * 1024))

# HELP nvidia_memory_total_bytes Total memory in bytes
# TYPE nvidia_memory_total_bytes gauge
nvidia_memory_total_bytes{index="$index",name="$name"} $((total * 1024 * 1024))

# HELP nvidia_temperature_celsius GPU temperature in celsius
# TYPE nvidia_temperature_celsius gauge
nvidia_temperature_celsius{index="$index",name="$name"} $temp

# HELP nvidia_power_draw_watts Power draw in watts
# TYPE nvidia_power_draw_watts gauge
nvidia_power_draw_watts{index="$index",name="$name"} $power
EOF
done
```

---

## Alerting

### High GPU Alert

```bash
#!/bin/bash
# gpu-alert.sh — Alert if GPU usage too high

THRESHOLD=${1:-90}

UTIL=$(nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits | head -1)

if [ "$UTIL" -ge "$THRESHOLD" ]; then
  echo "ALERT: GPU utilization at ${UTIL}% (threshold: ${THRESHOLD}%)"
  # Send alert (integrate with your alerting system)
  # curl -X POST "$WEBHOOK_URL" -d "GPU Alert: ${UTIL}%"
fi
```

---

## Skill Commands

| Command | Description |
|---------|-------------|
| `gpu status` | Show GPU status |
| `gpu status-json` | GPU status as JSON |
| `gpu summary` | Summary stats across all GPUs |
| `gpu watch` | Real-time monitoring |
| `gpu decide-scale` | Auto-scaling decision |
| `gpu pool-capacity <model>` | Calculate max pods for model |
| `gpu prometheus` | Prometheus-format metrics |
| `gpu alert <threshold>` | Alert if over threshold |
| `gpu temps` | Temperature readings |
| `gpu power` | Power consumption |

---

## Files

- `scripts/gpu-status-json.sh` — JSON GPU status
- `scripts/gpu-summary.sh` — Summary stats
- `scripts/gpu-decide-scale.sh` — Scaling decisions
- `scripts/gpu-pool-capacity.sh` — Capacity calculator
- `scripts/gpu-prometheus-metrics.sh` — Prometheus metrics
- `scripts/gpu-alert.sh` — Alerting script
## Quick Commands
- `skill-load gpu-monitor` — Load this skill
