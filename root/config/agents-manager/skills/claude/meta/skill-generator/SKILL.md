---
name: skill-generator
description: Generate new skills from global learnings - run every 3 days to create skills from accumulated lessons
trigger: /skill-generator or every 3 days
---

# Skill Generator

Generate new skills from global learnings. Run this every 3 days to create skills from accumulated lessons.

## When to Use

- Running `/skill-generator` command
- Every 3 days (schedule via `/loop 3d /skill-generator`)
- When enough new learnings have accumulated

## Steps

### 1. Collect Global Learnings
Read all files in:
- `/root/.claude/.lessons/*.md` - Cross-project learnings
- `/root/.claude/lessons/*.md` - Cross-project lessons

### 2. Analyze for Skill Opportunities
Identify patterns that would benefit from automation:
- Repeated workflows → new command skill
- Common patterns → new pattern skill
- Bug patterns → new debug skill
- Process improvements → new workflow skill

### 3. Evaluate Learnings
For each learning, assess:
- **Frequency**: How often does this pattern appear?
- **Impact**: Would automation save significant time?
- **Reusability**: Does it apply across multiple projects?
- **Complexity**: Is it complex enough to warrant a skill?

### 4. Create New Skill
For high-value learnings, create new skill:
```markdown
---
name: [skill-name]
description: [What the skill does]
trigger: /[command] or when [condition]
---

# [Skill Name]

[Detailed skill content]

## When to Use

- [Condition 1]
- [Condition 2]

## Steps

### 1. [Step]
[Description]

### 2. [Step]
[Description]

## Output

[Expected output]

## Notes

- [Note 1]
- [Note 2]
```

### 5. Update Global Learnings
After creating skill, mark the learning as "skill-created" in the source file.

### 6. Report
Generate a report of:
- New skills created
- Skills considered but not created (with reason)
- Recommendations for manual process improvements

## Output

After skill generation:
- New skills in `/root/.claude/skills/[skill-name]/SKILL.md`
- Updated source learnings with "skill-created" markers
- Summary report

## Scheduling

Set up recurring execution:
```
/loop 3d /skill-generator
```

This runs the skill generator every 3 days to continuously improve the skill library.

## Notes

- Only create skills for high-impact, reusable learnings
- Reject learnings that are too project-specific
- Consider modifying existing skills before creating new ones
- Document why each skill was created
## Quick Commands
- `skill-load skill-generator` — Load this skill
