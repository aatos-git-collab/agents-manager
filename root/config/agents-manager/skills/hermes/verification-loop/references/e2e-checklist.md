# E2E Testing Checklist

## Prerequisites
```bash
# Start services first
docker compose -f infra/docker-compose.yml -f infra/docker-compose.test.yml up -d
sleep 20  # wait for all services healthy
```

## Core Test Cases (Playwright)

### 1. Authentication Flow
- [ ] Login page loads at `/login`
- [ ] Can submit login form with valid credentials
- [ ] Shows error on invalid credentials
- [ ] Redirects to dashboard after login
- [ ] Logout works

### 2. Project Management
- [ ] Dashboard shows project list
- [ ] "New Project" button opens modal
- [ ] Can create project with name
- [ ] Project appears in list after creation
- [ ] Can click into a project → ProjectPage loads
- [ ] ProjectPage shows file tree, editor, preview

### 3. Builder/Editor (ProjectPage)
- [ ] File tree renders with modified files
- [ ] Clicking file shows content in Monaco editor
- [ ] Preview iframe loads the project URL
- [ ] Chat panel opens/closes
- [ ] Can send chat message
- [ ] SSE streaming works (response appears in chunks)
- [ ] Build status shows in real-time (pending → building → success/failed)

### 4. Chat & AI Interaction
- [ ] Can type and send a message
- [ ] AI responds via SSE streaming (token by token)
- [ ] Chat history persists during session
- [ ] Diff is applied after AI responds
- [ ] File tree updates after diff applied

### 5. Preview & Container
- [ ] Preview URL loads the built app
- [ ] Preview refreshes after build
- [ ] Container status visible in UI (running/stopped/error)

### 6. Error States
- [ ] 404 page renders correctly
- [ ] Network error shows appropriate message
- [ ] Build failure shows error in UI with logs

## Running E2E Tests

### Option A: Docker exec (services already up)
```bash
docker compose -f infra/docker-compose.yml -f infra/docker-compose.test.yml exec -T frontend npx playwright test
```

### Option B: Docker run test service
```bash
docker compose -f infra/docker-compose.yml -f infra/docker-compose.test.yml run --rm test
```

### Option C: Using the runner script
```bash
./scripts/run-e2e.sh
```

## Playwright Config Location
```
frontend/playwright.config.ts
```

## Expected Output
```
✓ N tests passed (e.g., 18/18)
0 failures
```

## If tests fail
1. Capture full output
2. Send to frontend-dev via: `aatosteam inbox send <team> frontend-dev "FAILED: e2e\n<output>"`
3. Do NOT fix yourself
4. Wait for agent fix → re-run e2e → verify
