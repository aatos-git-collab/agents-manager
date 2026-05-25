---
name: banana-slides
description: Generate a PPTX presentation from a structured report using banana-slides AI. Use when the user wants to create a PowerPoint from an audit report, strategy document, or any structured content via the banana-slides REST API at http://localhost:5000. Claude generates slides autonomously as part of report production workflow — frontend only needed for manual editing.
metadata:
  version: 1.0.0
---

# Banana Slides — AI PPT Generator

Generate PPTX presentations from structured report content using the banana-slides REST API.

## Prerequisites

- banana-slides backend must be running at `http://localhost:5000`
- API has no access code by default
- All content is in Chinese (`zh`) by default

## When to Use

- User says "generate a PPTX", "create a presentation", "make slides from this report", "export to PowerPoint"
- User says "turn this audit into slides"
- User says "create a presentation from the report we just generated"
- Any time a structured report needs to be converted to a PowerPoint presentation

## Workflow

```
1. Transform report content → banana-slides outline format
2. Create project: POST /api/projects
3. Set outline: PUT /api/projects/{id}/outline
4. Generate descriptions: POST /api/projects/{id}/descriptions/generate
5. Poll status every 5s (max 60s) until status = DESCRIPTIONS_GENERATED
6. Export PPTX: GET /api/projects/{id}/export/pptx
7. Download file to /root/banana-slides/exports/
8. Report file path to user
```

## Input Format (Report Content)

```json
{
  "title": "報告標題",
  "slides": [
    {"title": "封面", "content": "副標題"},
    {"title": "章節一", "content": "描述"},
    {"part": "章節名稱", "pages": [
      {"title": "子頁面", "content": "內容"}
    ]}
  ]
}
```

**Format rules:**
- `title` (string, required): slide title
- `content` (string, optional): body text
- `part` (string, optional): section group name — must have `pages` array
- `pages` (array, optional): slides under this part

## API Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/projects` | Create project (body: `{"title": "..."}`) |
| PUT | `/api/projects/{id}/outline` | Set slide outline (body: slide array) |
| POST | `/api/projects/{id}/descriptions/generate` | Start description generation |
| GET | `/api/projects/{id}` | Get project status (poll for DESCRIPTIONS_GENERATED) |
| GET | `/api/projects/{id}/export/pptx` | Export PPTX |
| GET | `/files/{project_id}/exports/{filename}` | Download file |

Base URL: `http://localhost:5000`

## Polling

- Poll interval: 5 seconds
- Timeout: 60 seconds
- Check `status` field in GET response: `DRAFT` → `DESCRIPTIONS_GENERATED` → `IMAGES_GENERATED`
- If timeout: report "Description generation timed out after 60s"

## Output

- Save to: `/root/banana-slides/exports/{filename}.pptx`
- Create directory if it doesn't exist
- Report final file path to user

## Error Handling

| Situation | Action |
|-----------|--------|
| Backend not running | Inform user, suggest `cd /root/banana-slides && docker compose up -d` |
| Description timeout | "Description generation timed out after 60s" |
| Invalid outline JSON | Report JSON validation error |
| Export fails | Report API error message |
| Download fails | Report I/O error |

## Example

```bash
# Create project
curl -X POST http://localhost:5000/api/projects \
  -H "Content-Type: application/json" \
  -d '{"title": "日盛當舖審計報告"}'

# Set outline
curl -X PUT http://localhost:5000/api/projects/{id}/outline \
  -H "Content-Type: application/json" \
  -d '[{"title": "封面"}, {"part": "SEO", "pages": [{"title": "技術問題"}]}]'

# Generate
curl -X POST http://localhost:5000/api/projects/{id}/descriptions/generate

# Poll status until DESCRIPTIONS_GENERATED

# Export
curl http://localhost:5000/api/projects/{id}/export/pptx
```
## Quick Commands
- `skill-load banana-slides` — Load this skill
