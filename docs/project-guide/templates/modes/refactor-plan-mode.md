Rewrite or update existing planning documents because of new features, improvements, or to migrate legacy formats into the v2.x artifact template structure.

{% include "modes/_header-cycle.md" %}

## Targets

The following documents may need updating (in order):

1. `{{ spec_artifacts_path }}/concept.md` — artifact template: `templates/artifacts/concept.md`
2. `{{ spec_artifacts_path }}/features.md` — artifact template: `templates/artifacts/features.md`
3. `{{ spec_artifacts_path }}/tech-spec.md` — artifact template: `templates/artifacts/tech-spec.md`

Skip any document that does not exist. If a document already reflects the current state of the project, confirm with the developer and skip.

## Cycle Steps (for each document)

### Step 1: Understand the Change

Ask the developer what needs updating and why. This could be:
- **New features or improvements** — sections need to reflect new capabilities, architecture changes, or revised scope
- **Legacy migration** — the document predates the v2.x artifact template format and needs restructuring

### Step 2: Backup

Copy the existing document to `<doc_name>_old.md` before making changes:

```
docs/specs/concept.md → docs/specs/concept_old.md
```

This protects against uncommitted work being overwritten.

### Step 3: Read and Extract

Read the old document as the primary source of information. Read the corresponding artifact template at `templates/artifacts/<doc_name>.md` to understand the target structure and required sections.

Map the old document's content to the artifact template sections. Note what needs to change based on the developer's instructions from Step 1.

### Step 4: Fill Gaps

If any sections required by the artifact template are missing or need new content:

1. Note which sections are missing or outdated
2. Ask the developer for the missing information
3. Wait for the developer's response before proceeding

Do not invent content — only use information from the old document or the developer.

### Step 5: Generate Updated Document

Write the updated document using the artifact template structure, incorporating:
- Existing content that is still accurate
- Updates based on the developer's instructions
- Any new information provided by the developer

### Step 6: Legacy Content

If any information from the old document does not fit into the artifact template sections, append it to the end of the new document:

```markdown
---

## Legacy Content

<content that didn't map to any template section>
```

If all content mapped cleanly, omit this section.

### Step 7: Present for Approval

Present the completed document to the developer. Show:
- What changed and why
- Which sections were preserved, updated, or added
- Whether a Legacy Content section was added

Iterate as needed until the developer approves. Then proceed to the next document in the targets list.

### Step 8: Cleanup

After the developer approves, the `_old.md` backup can be deleted at the developer's discretion. Do not delete it automatically.
