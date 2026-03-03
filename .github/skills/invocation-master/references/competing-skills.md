# Analyzing Competing Skills

Before refining the target skill, read the frontmatter and trigger rules of all other skills to understand the competitive landscape.

## Where Skills Live

All skills are in `<root>/plugin/skills/`. Each skill has a `SKILL.md` file.

## What to Extract

For each competing skill, extract:
1. The YAML frontmatter (between the `---` delimiters) — specifically the `name` and `description` fields.
2. The `## Triggers` section (if it exists) — the bullet list of activation conditions.

## Extraction Script

Use this Python snippet to extract frontmatter and triggers from a SKILL.md file deterministically:

```python
import re

def extract_frontmatter_and_triggers(content: str) -> dict:
    """Extract YAML frontmatter and Triggers section from a SKILL.md."""
    result = {"frontmatter": "", "triggers": ""}

    # Extract YAML frontmatter between --- delimiters
    fm_match = re.match(r"^---\n(.*?\n)---", content, re.DOTALL)
    if fm_match:
        result["frontmatter"] = fm_match.group(1).strip()

    # Extract ## Triggers section (everything until next ## heading or EOF)
    trig_match = re.search(r"^## Triggers\n(.*?)(?=\n## |\Z)", content, re.DOTALL | re.MULTILINE)
    if trig_match:
        result["triggers"] = trig_match.group(1).strip()

    return result
```

## How to Use

1. Read each `SKILL.md` in `<root>/plugin/skills/*/SKILL.md`.
2. Apply the extraction above to get frontmatter and triggers for each skill.
3. Compare the target skill's frontmatter/triggers against competing skills to find:
   - **Overlap** — phrases or keywords that appear in both the target and a competitor, causing ambiguity.
   - **Weakness** — prompts where the competitor's description is a closer match than the target's.
4. Use these insights to make the target skill's frontmatter more distinctive without copying or conflicting with competitors.
