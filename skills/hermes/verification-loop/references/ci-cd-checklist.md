# CI/CD Validation Checklist

## Files to Inspect
```
.github/workflows/
├── ci.yml          # main CI pipeline
├── e2e.yml         # E2E test runner (optional)
└── release.yml     # deployment pipeline (optional)
```

## CI Pipeline Must Have

### 1. Checkout & Setup
```yaml
- uses: actions/checkout@v4
- uses: actions/setup-node@v4
  with:
    node-version: '22'
    cache: 'pnpm'
```

### 2. Install Dependencies
```yaml
- run: pnpm install --frozen-lockfile
```

### 3. Build Step
```yaml
- run: pnpm build
```

### 4. Test Step (Docker-based)
```yaml
# The CI must run tests inside Docker, not directly
- run: docker compose -f infra/docker-compose.yml -f infra/docker-compose.test.yml up --build test
```

### 5. Lint (optional but recommended)
```yaml
- run: pnpm lint
```

## Secrets Required (document these, not hardcoded)
- `DATABASE_URL` — PostgreSQL connection string
- `REDIS_URL` — Redis connection string
- `JWT_SECRET` — JWT signing secret
- `OPENAI_API_KEY` — AI provider key (if using OpenAI)
- Registry credentials (if pushing images)

## Validation Commands

### Check workflow syntax
```bash
# Using act (local CI runner)
act -j test  # dry run: act -j test --dryrun

# Or validate YAML manually
python3 -c "import yaml; yaml.safe_load(open('.github/workflows/ci.yml'))"
```

### What to verify manually
1. Workflow file is valid YAML
2. `on:` triggers: `push` to `main` and `pull_request`
3. Jobs run in order: install → build → test
4. Docker compose test command is present and correct
5. No secrets hardcoded (all via `${{ secrets.SECRET_NAME }}`)
6. Node version matches project (22)

## Failure Handling
If CI is broken:
1. Inspect the failed workflow run in `.github/workflows/`
2. Send to the agent who owns that area: `aatosteam inbox send <team> <agent> "FAILED: ci-cd\n<error>"`
3. Wait for fix → re-verify CI → mark complete

## Fast CI Local Check
```bash
# Validate all workflow files
for f in .github/workflows/*.yml; do
  echo "Checking $f..."
  python3 -c "import yaml; yaml.safe_load(open('$f'))" && echo "  OK" || echo "  FAIL"
done
```
