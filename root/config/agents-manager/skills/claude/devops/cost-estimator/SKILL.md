---
name: cost-estimator
description: 💰 Cost Estimator Skill
---

# 💰 Cost Estimator Skill

## Description

Calculate and report time and cost savings for automation tasks. Compare AI agent execution vs. manual human labor with market rates.

## Usage

### Generate Cost Report

```bash
# After completing a task
cost_estimator.report(
  task_name="Deploy application",
  manual_time_hours=4.5,
  agent_time_minutes=15,
  market_rate_per_hour=75,
  task_complexity="medium"
)
```

### Get Quick Estimate

```bash
# Before starting a task
estimate = cost_estimator.estimate(
  task_type="deployment",
  complexity="medium",
  server_count=3
)

# Returns: { estimated_time, cost_savings, confidence }
```

---

## Tool Functions

### report
Generate a cost savings report for completed work.

**Parameters:**
- `task_name` (string): Name of the task
- `manual_time_hours` (float): Time it would take a human
- `agent_time_minutes` (float): Time agent actually took
- `market_rate_per_hour` (float): Human labor rate ($/hr)
- `task_complexity` (string): "simple" | "medium" | "complex"
- `labor_type` (string): "devops" | "developer" | "sysadmin" | "dba"
- `skills_used` (array): Skills employed

**Returns:**
```json
{
  "task_name": "Deploy application",
  "time_saved_hours": 4.25,
  "cost_savings_usd": 318.75,
  "efficiency_gain": "94%",
  "market_rate": 75,
  "agent_cost": 0.05,
  "roi": "6,375x",
  "human_comparable": "1 day of DevOps work",
  "timestamp": "2026-02-12T19:45:00Z"
}
```

### estimate
Get pre-execution cost estimate.

**Parameters:**
- `task_type` (string): "deployment" | "monitoring" | "debugging" | "maintenance"
- `complexity` (string): "simple" | "medium" | "complex"
- `server_count` (int): Number of servers
- `labor_type` (string): Override default labor type

**Returns:**
```json
{
  "estimated_time_minutes": 15,
  "estimated_cost_usd": 0.19,
  "manual_time_hours": 4,
  "potential_savings_usd": 300,
  "confidence": "high",
  "breakdown": {
    "planning": "2 min",
    "execution": "8 min",
    "verification": "5 min"
  }
}
```

### get_market_rates
Get current market rates.

**Parameters:** None

**Returns:**
```json
{
  "rates": {
    "devops": 75,
    "developer": 100,
    "sysadmin": 65,
    "dba": 90,
    "sre": 110,
    "cloud_architect": 130
  },
  "source": "Indeed 2024",
  "updated": "2026-01-15"
}
```

### set_market_rate
Update market rate for labor type.

**Parameters:**
- `labor_type` (string): Labor category
- `rate_per_hour` (float): New rate

**Returns:** Confirmation

### generate_summary
Generate summary report for time period.

**Parameters:**
- `start_date` (string): ISO date
- `end_date` (string): ISO date

**Returns:**
```json
{
  "period": "2026-02-01 to 2026-02-12",
  "total_tasks": 47,
  "total_time_saved_hours": 156.5,
  "total_cost_savings_usd": 11737.50,
  "average_efficiency": "89%",
  "top_tasks": [
    {"name": "Deploy v2.0", "savings": 318.75},
    {"name": "Fix bug #123", "savings": 225.00}
  ],
  "labor_distribution": {
    "devops": 10000,
    "developer": 1737.50
  }
}
```

---

## Default Market Rates (2024)

| Role | Rate ($/hr) | Description |
|------|-------------|-------------|
| DevOps Engineer | $75 | Infrastructure, deployments |
| Senior Developer | $100 | Code, architecture |
| SysAdmin | $65 | Server management |
| DBA | $90 | Database administration |
| SRE | $110 | Site reliability |
| Cloud Architect | $130 | Cloud design |

---

## Example Reports

### Deployment Report

```
┌────────────────────────────────────────────────────┐
│  Job Complete: Production Deployment               │
├────────────────────────────────────────────────────┤
│  🕐 Time Saved: 4.5 hours                         │
│  💵 Market Rate: $75/hr (DevOps)                   │
│  💰 Cost Savings: $337.50                          │
│  ⏱️ Agent Time: 15 minutes                        │
│  📈 Efficiency: 94% faster                        │
│  🔄 ROI: 6,375x return on compute cost            │
├────────────────────────────────────────────────────┤
│  🎯 Comparable to: 1 day DevOps work              │
│  ✅ Status: COMPLETED                              │
└────────────────────────────────────────────────────┘
```

### Weekly Summary

```
┌────────────────────────────────────────────────────┐
│  📊 Weekly Report: Feb 5 - Feb 12                 │
├────────────────────────────────────────────────────┤
│  Total Tasks Completed: 47                         │
│  Total Time Saved: 156.5 hours                      │
│  Total Cost Savings: $11,737.50                    │
│  Average Efficiency: 89%                           │
├────────────────────────────────────────────────────┤
│  💪 Top Saver: Deploy v2.0 ($337.50)             │
│  🚀 Most Efficient: Health Check (98%)             │
│  📈 Total ROI: 15,000x                            │
└────────────────────────────────────────────────────┘
```

---

## Metrics Tracked

- Time saved per task
- Cost savings per task
- Cumulative savings
- Efficiency percentages
- ROI calculations
- Labor type distribution

---

## Best Practices

1. **Report every task** - Build accurate data
2. **Use accurate rates** - Update market rates quarterly
3. **Track complexity** - Better estimates over time
4. **Share reports** - Demonstrate value to stakeholders
5. **Set baselines** - Measure improvement

---

## Integration Points

- **agent-coordinator:** Use for task completion reports
- **report-generator:** Include in daily/weekly reports
- **dashboard-builder:** Display cost metrics
- **notification-sender:** Alert on significant savings

---

## Configuration

```yaml
cost_estimator:
  default_rate: 75  # Default $/hr
  labor_types:
    devops: 75
    developer: 100
    sysadmin: 65
    dba: 90
    sre: 110
  currency: "USD"
  output_format: "detailed"  # "detailed" | "summary" | "minimal"
```

---

## Future Enhancements

- [ ] Multi-currency support
- [ ] Regional rate adjustments
- [ ] Historical trend analysis
- [ ] Predictive cost estimation
- [ ] Integration with billing systems

---

*Skill Version: 1.0.0*
*For: Cost Analysis & Reporting*
