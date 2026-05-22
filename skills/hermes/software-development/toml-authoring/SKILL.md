---
name: toml-authoring
description: Safe patterns for programmatically writing TOML files — especially templates with multi-line strings, backslash-heavy content (regex, commands), and dynamic injection via .format(). Avoids common pitfalls with TOML escapes and Python string handling.
trigger: when writing .toml files programmatically, especially template systems or config generators
---

# TOML Authoring — Safe Patterns

## The Core Problem

When writing TOML files programmatically with dynamic content, two classes of bugs appear:
1. Backslash escapes: TOML basic strings require `\\` for a literal `\`, and `\|` is **illegal**
2. Multi-line values: `.format()` injects newlines, so `task = "{}"` breaks if content has line breaks

## Golden Rules

1. **Never use `re.sub()` on raw TOML** — you'll corrupt table/array syntax (`[[foo]]` → `[\[foo\]]`)
2. **Always double-escape backslashes** for TOML basic strings: `s.replace("\\", "\\\\")`
3. **Use `"""..."""` (triple quotes) for multi-line TOML values**, never `"..."`
4. **Use temp files for complex content** — avoids Python string quoting hell with backslashes

## Pattern 1: Simple TOML (no complex strings)

```python
import tomllib

content = f'''
[template]
name = "{name}"
description = "{description}"
command = ["claude"]
backend = "tmux"

[template.leader]
name = "{leader_name}"
type = "{leader_type}"
task = "{task_content}"   # Only if task_content has NO newlines
'''
```

## Pattern 2: Complex Multi-Line Content (RECOMMENDED)

```python
import tomllib

def esc(s):
    """Escape backslashes for TOML basic strings."""
    return s.replace("\\", "\\\\")

# Write complex content to temp files FIRST (avoids Python string quoting hell)
with open("/tmp/leader_task.txt", "w") as f:
    f.write(r"""Your task here with backslashes like grep -r "foo|bar"
And newlines are fine.
""")

leader_task = open("/tmp/leader_task.txt").read()

content = f'''
[template.leader]
name = "orchestrator"
task = """{task}"""
'''.format(task=esc(leader_task))

with open("output.toml", "w") as f:
    f.write(content)

# Validate
with open("output.toml", "rb") as f:
    data = tomllib.load(f)
```

## Pattern 3: Multi-Agent Template (Definitive Pattern)

```python
import tomllib

def esc(s):
    """Escape backslashes for TOML basic strings."""
    return s.replace("\\", "\\\\")

# Each agent task: write to temp file
with open("/tmp/leader.txt", "w") as f:
    f.write(r"""Leader prompt with backslashes: grep -r "pattern|regex"
And newlines.
""")

with open("/tmp/worker.txt", "w") as f:
    f.write(r"""Worker prompt.
""")

leader = open("/tmp/leader.txt").read()
worker = open("/tmp/worker.txt").read()

toml_body = f'''
[template]
name = "my-template"
description = "My template"
command = ["claude"]
backend = "tmux"

[template.leader]
name = "leader"
type = "leader-type"
task = """{leader_esc}"""

[[template.agents]]
name = "worker"
type = "worker-type"
task = """{worker_esc}"""

[[template.tasks]]
subject = "First task"
owner = "leader"
'''.format(leader_esc=esc(leader), worker_esc=esc(worker))

with open("my-template.toml", "w") as f:
    f.write(toml_body)

with open("my-template.toml", "rb") as f:
    tomllib.load(f)  # Validate
```

## Common TOML Escape Mistakes

| What you wrote | What TOML sees | Error |
|----------------|----------------|-------|
| `"grep -r "foo|bar""` | `foo|bar` — `\|` is illegal escape | `TOMLDecodeError: Unescaped '\'` |
| `"C:\path\to\file"` | `C:\path\to\file` — `\p` illegal | `TOMLDecodeError: Unescaped '\'` |
| `\|` in basic string | invalid escape | same |
| `"multi\nline"` | `\n` treated as newline escape | ok but not what you want |

**Fix:** Use `r"raw string"` to write the content, then `s.replace("\\", "\\\\")` to double-escape.

## Triple-Quote Trap

```python
# WRONG — .format() injects newlines into single-line string
content = '''
[section]
task = "{body}"
'''.format(body="line1\nline2")  # TOML parse error: \n in single-line string

# RIGHT — use triple quotes in TOML
content = '''
[section]
task = """{body}"""
'''.format(body=esc("line1\nline2"))  # valid
```

## Validate After Every Write

```python
import tomllib

with open("file.toml", "rb") as f:
    data = tomllib.load(f)
print("VALID")
```

Always validate — TOML errors are silent until parse time.

## Why Temp Files?

Python string literals + backslashes + triple quotes + `.format()` = quoting nightmare:

```python
# This is a SYNTAX ERROR in Python — can't nest """
task = """..."""  # can't put """ inside """

# This compiles but writes WRONG content (escapes are wrong for TOML)
task = """backslashes: \\ are tricky"""

# Safe: write to file, read back
with open("/tmp/task.txt", "w") as f:
    f.write(r"""backslashes: \ are tricky""")
task = open("/tmp/task.txt").read()  # clean string, then double-escape for TOML
```
## Quick Commands
- `skill-load toml-authoring` — Load this skill
