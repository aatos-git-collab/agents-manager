---
name: saas-management
description: Skill: saas-management
---

# Skill: saas-management

**Category:** devops
**Version:** 1.0.0
**Author:** Hermes (Root Agent)
**Date:** 2026-03-31

## Description

Manages SaaS multi-tenant infrastructure — PostgreSQL for management (users, orgs, billing), S3 for company-in-a-box persistence (backup, sync), and company-in-a-box local SQLite with S3 sync.

## Trigger Conditions

Use when:
- Setting up SaaS management database
- Managing tenants/organizations
- Configuring S3 backup for company-in-a-box
- Setting up billing/cubscription tracking
- Migrating company data to/from S3
- Managing storage quotas

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                     SaaS Management Layer                        │
│                    (PostgreSQL - hosted)                         │
│                                                                  │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐     │
│  │  users   │  │  orgs   │  │ billing  │  │  quotas  │     │
│  └──────────┘  └──────────┘  └──────────┘  └──────────┘     │
└─────────────────────────────────────────────────────────────────┘
                              │
                              │ S3 sync
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                   Company-in-a-Box (Local)                        │
│                                                                  │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │ Local SQLite (per company)                               │   │
│  │  • sessions/  • memory/  • trajectories/                │   │
│  │  • skills/  • workspace/                                │   │
│  └─────────────────────────────────────────────────────────┘   │
│                              │                                   │
│                              │ S3 Backup/Sync                    │
│                              ▼                                   │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │ S3 Bucket: s3://hermes-saas/<org_id>/                   │   │
│  │  • backup/   • sync/   • archives/                      │   │
│  └─────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

---

## PostgreSQL Schema

### Users Table

```sql
CREATE TABLE users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email VARCHAR(255) UNIQUE NOT NULL,
  password_hash VARCHAR(255) NOT NULL,
  name VARCHAR(255),
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW(),
  last_login TIMESTAMP,
  is_active BOOLEAN DEFAULT true,
  is_superadmin BOOLEAN DEFAULT false
);

CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_org ON users(org_id);
```

### Organizations Table

```sql
CREATE TABLE orgs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name VARCHAR(255) NOT NULL,
  slug VARCHAR(100) UNIQUE NOT NULL,
  plan VARCHAR(50) DEFAULT 'free',
  status VARCHAR(50) DEFAULT 'active',
  settings JSONB DEFAULT '{}',
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_orgs_slug ON orgs(slug);
CREATE INDEX idx_orgs_plan ON orgs(plan);
```

### Subscriptions/Billing

```sql
CREATE TABLE subscriptions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id UUID REFERENCES orgs(id) ON DELETE CASCADE,
  plan VARCHAR(50) NOT NULL,
  status VARCHAR(50) DEFAULT 'active',
  current_period_start TIMESTAMP,
  current_period_end TIMESTAMP,
  cancel_at_period_end BOOLEAN DEFAULT false,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE invoices (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id UUID REFERENCES orgs(id) ON DELETE CASCADE,
  amount_cents INTEGER NOT NULL,
  currency VARCHAR(3) DEFAULT 'USD',
  status VARCHAR(50) DEFAULT 'pending',
  paid_at TIMESTAMP,
  created_at TIMESTAMP DEFAULT NOW()
);
```

### Usage Quotas

```sql
CREATE TABLE quotas (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id UUID REFERENCES orgs(id) ON DELETE CASCADE,
  resource VARCHAR(100) NOT NULL,
  limit_value BIGINT NOT NULL,
  used_value BIGINT DEFAULT 0,
  period VARCHAR(20) DEFAULT 'monthly',
  updated_at TIMESTAMP DEFAULT NOW(),
  UNIQUE(org_id, resource, period)
);

-- Default quotas per plan
INSERT INTO quotas (org_id, resource, limit_value) 
SELECT id, 'agents', 5 FROM orgs WHERE plan = 'free';
INSERT INTO quotas (org_id, resource, limit_value) 
SELECT id, 'storage_gb', 10 FROM orgs WHERE plan = 'free';
INSERT INTO quotas (org_id, resource, limit_value) 
SELECT id, 'api_calls', 1000 FROM orgs WHERE plan = 'free';
```

### API Keys

```sql
CREATE TABLE api_keys (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id UUID REFERENCES orgs(id) ON DELETE CASCADE,
  name VARCHAR(255),
  key_hash VARCHAR(255) NOT NULL,
  last_used TIMESTAMP,
  created_at TIMESTAMP DEFAULT NOW(),
  expires_at TIMESTAMP
);

CREATE INDEX idx_api_keys_org ON api_keys(org_id);
```

---

## S3 Structure

### Bucket Structure

```
s3://hermes-saas/
├── <org_id>/
│   ├── backup/
│   │   ├── 2026-03-31/
│   │   │   ├── sessions.tar.gz
│   │   │   ├── memory.tar.gz
│   │   │   └── trajectories.tar.gz
│   │   └── 2026-04-01/
│   ├── sync/
│   │   ├── current/
│   │   │   ├── sessions/
│   │   │   ├── memory/
│   │   │   └── workspace/
│   │   └── manifest.json
│   ├── archives/
│   │   └── old-workspace-2026-01.tar.gz
│   └── config/
│       └── company-config.json
```

### S3 Lifecycle Rules

- `backup/` — Daily backups, retain 30 days
- `sync/` — Always current, sync on every session end
- `archives/` — Manual archives, retain until deleted

---

## Company-in-a-Box Local Storage

### Local Directory Structure

```
/data/<org_id>/
├── .config/
│   └── company.json          # Company metadata
├── sessions/
│   └── <session_id>.db       # SQLite per session
├── memory/
│   └── <vector_store>        # Vector embeddings
├── trajectories/
│   └── <run_id>.jsonl       # RL training data
├── skills/
│   └── <skill_name>/         # Installed skills
├── workspace/
│   └── <project>/            # Project files
└── .sync/
    └── last_sync.json        # Last S3 sync timestamp
```

---

## Management Commands

### PostgreSQL Commands

```bash
#!/bin/bash
# psql-connect.sh — Connect to SaaS PostgreSQL

PGHOST=${PGHOST:-localhost}
PGPORT=${PGPORT:-5432}
PGDATABASE=${PGDATABASE:-hermes_saas}
PGUSER=${PGUSER:-hermes_admin}

psql -h "$PGHOST" -p "$PGPORT" -d "$PGDATABASE" -U "$PGUSER"
```

### Organization Commands

```bash
#!/bin/bash
# org-create.sh <name> <slug> <plan>

NAME=$1
SLUG=$2
PLAN=${3:-"free"}

ORG_ID=$(psql -t -c "
  INSERT INTO orgs (name, slug, plan) 
  VALUES ('$NAME', '$SLUG', '$PLAN') 
  RETURNING id;
" | tr -d ' ')

echo "Created org: $SLUG (ID: $ORG_ID)"

# Create default quotas
psql -c "
  INSERT INTO quotas (org_id, resource, limit_value) VALUES 
  ('$ORG_ID', 'agents', $([ "$PLAN" = "free" ] && echo 5 || echo 50)),
  ('$ORG_ID', 'storage_gb', $([ "$PLAN" = "free" ] && echo 10 || echo 1000)),
  ('$ORG_ID', 'api_calls', $([ "$PLAN" = "free" ] && echo 1000 || echo 100000));
"

echo "Default quotas created"
```

### S3 Commands

```bash
#!/bin/bash
# s3-sync-up.sh <org_id> — Sync local data to S3

ORG_ID=$1
LOCAL_DIR="/data/$ORG_ID"
S3_BUCKET="s3://hermes-saas/$ORG_ID"

echo "Syncing $ORG_ID to S3..."

# Sync workspace (incremental)
aws s3 sync "$LOCAL_DIR/workspace/" "$S3_BUCKET/sync/current/workspace/" \
  --storage-class STANDARD_IA

# Backup sessions (compressed)
tar -czf "/tmp/sessions-$ORG_ID.tar.gz" -C "$LOCAL_DIR" sessions/
aws s3 cp "/tmp/sessions-$ORG_ID.tar.gz" \
  "$S3_BUCKET/backup/$(date +%Y-%m-%d)/sessions.tar.gz"

# Update manifest
cat > "$LOCAL_DIR/.sync/last_sync.json" << EOF
{
  "last_sync": "$(date -Iseconds)",
  "org_id": "$ORG_ID",
  "s3_path": "$S3_BUCKET"
}
EOF

aws s3 cp "$LOCAL_DIR/.sync/last_sync.json" \
  "$S3_BUCKET/sync/manifest.json"

echo "Sync complete"
```

### S3 Restore

```bash
#!/bin/bash
# s3-restore.sh <org_id> [date] — Restore from S3 backup

ORG_ID=$1
DATE=${2:-$(date +%Y-%m-%d)}
LOCAL_DIR="/data/$ORG_ID"
S3_BUCKET="s3://hermes-saas/$ORG_ID"

echo "Restoring $ORG_ID from $DATE..."

# Create local directory
mkdir -p "$LOCAL_DIR"

# Restore workspace
aws s3 sync "$S3_BUCKET/sync/current/workspace/" "$LOCAL_DIR/workspace/"

# Restore sessions
aws s3 cp "$S3_BUCKET/backup/$DATE/sessions.tar.gz" "/tmp/"
tar -xzf "/tmp/sessions-$ORG_ID.tar.gz" -C "$LOCAL_DIR/"

echo "Restore complete"
```

---

## Quota Management

### Check Quota

```bash
#!/bin/bash
# quota-check.sh <org_id> <resource>

ORG_ID=$1
RESOURCE=$2

psql -t -c "
  SELECT 
    resource,
    limit_value,
    used_value,
    CASE 
      WHEN used_value >= limit_value THEN 'EXCEEDED'
      WHEN used_value >= limit_value * 0.9 THEN 'WARNING'
      ELSE 'OK'
    END as status
  FROM quotas 
  WHERE org_id = '$ORG_ID' AND resource = '$RESOURCE';
" | column -t
```

### Enforce Quota

```sql
-- Function to check and enforce quota
CREATE OR REPLACE FUNCTION check_quota(
  p_org_id UUID,
  p_resource VARCHAR,
  p_increment BIGINT DEFAULT 1
) RETURNS BOOLEAN AS $$
DECLARE
  v_quota RECORD;
  v_allowed BOOLEAN;
BEGIN
  SELECT * INTO v_quota FROM quotas 
  WHERE org_id = p_org_id AND resource = p_resource;
  
  IF NOT FOUND THEN
    RETURN TRUE;  -- No quota set, allow
  END IF;
  
  IF v_quota.used_value + p_increment > v_quota.limit_value THEN
    RETURN FALSE;  -- Quota exceeded
  END IF;
  
  UPDATE quotas SET used_value = used_value + p_increment
  WHERE org_id = p_org_id AND resource = p_resource;
  
  RETURN TRUE;
END;
$$ LANGUAGE plpgsql;
```

---

## Billing Integration

### Create Invoice

```bash
#!/bin/bash
# invoice-create.sh <org_id> <amount_cents>

ORG_ID=$1
AMOUNT=$2

psql -c "
  INSERT INTO invoices (org_id, amount_cents, status)
  VALUES ('$ORG_ID', $AMOUNT, 'pending');
"

echo "Invoice created for org $ORG_ID: $AMOUNT cents"
```

### Subscription Management

```bash
#!/bin/bash
# subscription-upgrade.sh <org_id> <new_plan>

ORG_ID=$1
NEW_PLAN=$2

psql -c "
  UPDATE orgs SET plan = '$NEW_PLAN', updated_at = NOW()
  WHERE id = '$ORG_ID';
  
  UPDATE subscriptions SET status = 'canceled', updated_at = NOW()
  WHERE org_id = '$ORG_ID' AND status = 'active';
  
  INSERT INTO subscriptions (org_id, plan, status, current_period_start, current_period_end)
  VALUES (
    '$ORG_ID',
    '$NEW_PLAN',
    'active',
    NOW(),
    NOW() + INTERVAL '1 month'
  );
"

# Update quotas for new plan
case $NEW_PLAN in
  starter)
    AGENTS=10; STORAGE=50; API=10000 ;;
  pro)
    AGENTS=50; STORAGE=500; API=100000 ;;
  enterprise)
    AGENTS=-1; STORAGE=-1; API=-1 ;;  # Unlimited
esac

psql -c "
  UPDATE quotas SET limit_value = $AGENTS WHERE org_id = '$ORG_ID' AND resource = 'agents';
  UPDATE quotas SET limit_value = $STORAGE WHERE org_id = '$ORG_ID' AND resource = 'storage_gb';
  UPDATE quotas SET limit_value = $API WHERE org_id = '$ORG_ID' AND resource = 'api_calls';
"

echo "Upgraded org $ORG_ID to $NEW_PLAN"
```

---

## Health Checks

```bash
#!/bin/bash
# saas-health.sh — Health check for SaaS infrastructure

echo "=== SaaS Health Check ==="

# PostgreSQL
if pg_isready -h localhost -p 5432 > /dev/null 2>&1; then
  echo "✓ PostgreSQL: OK"
else
  echo "✗ PostgreSQL: DOWN"
fi

# S3
if aws s3 ls s3://hermes-saas/ > /dev/null 2>&1; then
  echo "✓ S3: OK"
else
  echo "✗ S3: DOWN"
fi

# Check disk space on data volume
DISK_USAGE=$(df -h /data | awk 'NR==2 {print $5}' | tr -d '%')
if [ "$DISK_USAGE" -lt 80 ]; then
  echo "✓ Disk Space: OK (${DISK_USAGE}% used)"
else
  echo "⚠ Disk Space: WARNING (${DISK_USAGE}% used)"
fi
```

---

## Skill Commands

| Command | Description |
|---------|-------------|
| `saas db connect` | Connect to PostgreSQL |
| `saas org create <name> <slug> [plan]` | Create organization |
| `saas org list` | List all orgs |
| `saas org upgrade <org_id> <plan>` | Upgrade org plan |
| `saas quota check <org_id> <resource>` | Check quota usage |
| `saas quota set <org_id> <resource> <limit>` | Set quota limit |
| `saas backup <org_id>` | Backup org to S3 |
| `saas restore <org_id> [date]` | Restore org from S3 |
| `saas sync status <org_id>` | Show sync status |
| `saas invoice create <org_id> <amount>` | Create invoice |
| `saas health` | Health check all services |
| `saas user create <email> <org_id>` | Create user |
| `saas api-key create <org_id> <name>` | Create API key |
## Quick Commands
- `skill-load saas-management` — Load this skill
