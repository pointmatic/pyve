# Phase 0: Project Basics Questions

## Overview

**Phase:** 0 (Project Basics)  
**When:** Immediately after `pyve --init`  
**Duration:** 5-10 minutes  
**Questions:** 6-11 total (varies by Quality level)  
**Outcome:** Minimal viable spec to start Phase 0 implementation (v0.0.x)

**Before starting:** Read `llm_qa_principles__t__.md` to understand Q&A methodology.

## Topics Covered

- Quality level selection
- Project overview (problem, users, success criteria)
- Language and framework
- Component structure
- Repository basics
- Optional: Key constraints (production/secure only)

## Question Templates

### Quality Level Selection (Required)

**Context:** The Quality level determines how much rigor we apply to testing, security, and operations.

**Question:**
```
What Quality level best describes this project?

- **experiment**: Testing an idea, throwaway code acceptable (hours to days)
  - Minimal tests, no production deployment
  - Example: "Try out a new API to see if it works"

- **prototype**: Validate functionality or UX (days to weeks)
  - Basic error handling, smoke tests
  - Example: "Build a demo to show stakeholders"

- **production**: Reliable service for real users (weeks to months)
  - Full testing, monitoring, CI/CD, on-call readiness
  - Example: "Internal tool used daily by the team"

- **secure**: Production + compliance and hardening (months+)
  - Threat modeling, audits, regulatory compliance
  - Example: "Healthcare app handling patient data"

Which level? [experiment/prototype/production/secure]
```

**Follow-up (if unclear):**
- "Will this be used by real users in production?" → production or secure
- "Is this just for learning/testing?" → experiment
- "Do you need to comply with regulations (GDPR, HIPAA, etc.)?" → secure

**Fills:** `docs/specs/codebase_spec.md` (Quality section), `docs/specs/technical_design_spec.md` (Quality section)

---

### Project Overview (Required)

**Question 1: Problem Statement**
```
What specific problem does this project solve?

Be concrete. Instead of "manage data," say "import CSV files and generate reports."

Example: "Merge multiple markdown files into a single document for LLM context windows"
```

**Fills:** `docs/specs/technical_design_spec.md` (Overview section)

---

**Question 2: Target Users**
```
Who will use this project?

- End users (customers, public)
- Internal team (developers, ops, analysts)
- Other systems (APIs, integrations)
- Just you (personal tool)

Example: "Developers on my team who work with LLMs"
```

**Fills:** `docs/specs/technical_design_spec.md` (Overview section)

---

**Question 3: Success Criteria** (skip for experiment)
```
What does success look like? How will you know this project works?

Example: "Successfully merges 10+ markdown files without data loss, runs in under 1 second"
```

**Fills:** `docs/specs/technical_design_spec.md` (Goals section)

---

### Language and Framework (Required)

**Question 4: Primary Language**
```
What programming language will you use?

Common choices:
- Python (data, ML, scripting, web)
- Shell (bash/zsh for system automation)
- JavaScript/TypeScript (web, Node.js)
- Go (performance, CLI tools, services)
- Other: [specify]

Language: ___________
Version/runtime: ___________ (e.g., Python 3.11+, Node 20+)
```

**Fills:** `docs/specs/codebase_spec.md` (Runtime & Platforms section), `docs/specs/implementation_options_spec.md` (Languages & Runtimes section)

---

**Question 5: Framework** (if applicable)
```
Will you use a framework?

For Python:
- Web: Flask, FastAPI, Django, Streamlit, Reflex
- CLI: Click, Typer, argparse
- None (plain Python)

For JavaScript:
- Web: React, Vue, Svelte, Next.js
- Backend: Express, Fastify
- None (vanilla JS)

Framework: ___________ (or "none")
```

**Fills:** `docs/specs/implementation_options_spec.md` (Frameworks section)

---

### Component Structure (Required)

**Question 6: Project Type**
```
What type of project is this?

- **application**: Standalone program with entry point (CLI, web app, service)
- **library**: Reusable code for other projects (package, module)
- **script**: Single-file utility or automation
- **mixed**: Multiple components (e.g., library + CLI)

Type: ___________
```

**Fills:** `docs/specs/codebase_spec.md` (Components section)

---

**Question 7: Deliverable** (skip for experiment)
```
How will this be packaged and distributed?

- **none**: Source code only, run directly
- **wheel/package**: Python wheel, npm package, gem, etc.
- **binary**: Compiled executable
- **container**: Docker/Podman image
- **other**: [specify]

Packaging: ___________
```

**Fills:** `docs/specs/codebase_spec.md` (Build & Packaging section), `docs/specs/implementation_options_spec.md` (Packaging & Distribution section)

---

### Repository Basics (Required)

**Question 8: Repository Name**
```
What's the repository/project name?

Use lowercase with hyphens or underscores (e.g., merge-docs, data_pipeline)

Name: ___________
```

**Fills:** `docs/specs/codebase_spec.md` (Repository section)

---

**Question 9: Repository Location & Visibility**
```
Where will this repository be hosted?

**Provider:**
- **GitHub**: github.com (most common)
- **GitLab**: gitlab.com or self-hosted
- **Bitbucket**: bitbucket.org
- **Other**: [specify]

**Visibility:**
- **private**: Only accessible to you/your team (default for most projects)
- **public**: Open source, anyone can view

**URL:** ___________ (e.g., https://github.com/username/repo-name)

If not created yet, say "not created yet" and I'll help you set it up later.

Provider: ___________
Visibility: ___________
URL: ___________
```

**Follow-up (if unclear):**
- "Will this be open source?" → public
- "Just for your team?" → private
- "Not sure yet?" → Use "private" as default (can change later)

**Fills:** `docs/specs/codebase_spec.md` (Repository section: URL, Provider, Visibility)

---

**Question 10: Deployment** (skip for experiment)
```
Will this be deployed to a server/cloud, or run locally?

- **local**: Runs on developer machines only
- **deployed**: Hosted on Fly.io, AWS, GCP, Azure, Heroku, etc.
- **both**: Local development + deployed production

Deployment: ___________

If deployed, which platform? ___________
```

**Fills:** `docs/specs/codebase_spec.md` (Infrastructure section), `docs/specs/implementation_options_spec.md` (Infrastructure & Hosting section)

---

### Optional: Constraints (production/secure only)

**Question 11: Key Constraints**
```
Are there any critical constraints I should know about?

Examples:
- Compliance: "Must be HIPAA compliant"
- Performance: "Must handle 10K requests/second"
- Budget: "Free tier only, no paid services"
- Timeline: "Must launch in 2 weeks"
- Legacy: "Must integrate with existing Oracle database"

Constraints: ___________ (or "none")
```

**Fills:** `docs/specs/implementation_options_spec.md` (Context and Constraints section)

---

## Example Q&A Session: Experiment-Level CLI Tool

**LLM:** I'll help you fill out the project specifications. This should take about 5-10 minutes. We'll start with Phase 0 (project basics). You can say "I don't know yet" or "use defaults" for any question.

---

**LLM:** What Quality level best describes this project?

- **experiment**: Testing an idea, throwaway code acceptable
- **prototype**: Validate functionality or UX  
- **production**: Reliable service for real users
- **secure**: Production + compliance and hardening

**Developer:** Experiment. I just want to test if this idea works.

---

**LLM:** Got it. What specific problem does this project solve?

**Developer:** I want to merge multiple markdown files into one file so I can paste it to an LLM.

---

**LLM:** Who will use this project?

**Developer:** Just me, for now.

---

**LLM:** What programming language will you use?

**Developer:** Python 3.11

---

**LLM:** Will you use a framework? For Python CLI tools, common choices are Click, Typer, or plain argparse.

**Developer:** Let's use Click.

---

**LLM:** What type of project is this?
- application (standalone program)
- library (reusable code)
- script (single file)

**Developer:** Application. A CLI tool.

---

**LLM:** What's the repository/project name?

**Developer:** merge-docs

---

**LLM:** Where will this repository be hosted? For example, GitHub, GitLab, or Bitbucket?

**Developer:** GitHub. It's not created yet though.

**LLM:** No problem. Will it be public (open source) or private (just for you)?

**Developer:** Private for now.

---

**LLM:** Will this be deployed to a server, or run locally?

**Developer:** Just local, on my machine.

---

**LLM:** Perfect! Here's what I understand:

**Project:** merge-docs  
**Repository:** GitHub (private, not created yet)  
**Purpose:** Merge multiple markdown files into one for LLM context  
**Users:** Personal tool  
**Quality:** Experiment  
**Language:** Python 3.11  
**Framework:** Click  
**Type:** CLI application  
**Deployment:** Local only  

Does this look correct?

**Developer:** Yes, looks good.

---

**LLM:** Great! I've filled out the Phase 0 specifications in:
- `docs/specs/codebase_spec.md` (Quality, Components, Runtime)
- `docs/specs/technical_design_spec.md` (Overview, Goals)
- `docs/specs/implementation_options_spec.md` (Language selection)

You're ready to start Phase 0 implementation (v0.0.0 - project setup).

Would you like me to:
1. Start implementing v0.0.0 (create project structure, setup.py, basic CLI)
2. Review the specs first
3. Ask more detailed questions (Phase 1)

**Developer:** Let's start implementing v0.0.0.

---

## Summary: What Gets Filled Out

After Phase 0 Q&A, the following spec sections should be populated:

### `docs/specs/codebase_spec.md`
- Repository (name, URL, provider, visibility, summary, status, owners)
- Quality (level and guidance)
- Components (name, kind, language, paths, entrypoints, audience)
- Runtime & Platforms (OS targets, CPU/arch, language runtimes)
- Build & Packaging (build systems, artifacts, versioning)
- Infrastructure (if deployed: provider, platform config)

### `docs/specs/technical_design_spec.md`
- Overview (problem, users, outcomes)
- Goals and Non-Goals (measurable objectives, out-of-scope items)
- Quality (level and entry/exit criteria)

### `docs/specs/implementation_options_spec.md`
- Context and Constraints (business goals, constraints, assumptions)
- Quality (level and guidance)
- Languages & Runtimes (candidates, considerations, selection)
- Frameworks (candidates, considerations, selection)
- Packaging & Distribution (candidates, considerations, selection)
- Infrastructure & Hosting (if deployed: candidates, considerations, selection)

## Next Steps

After completing Phase 0 Q&A:

1. **Review specs with developer** - Confirm everything looks correct
2. **Start Phase 0 implementation** - v0.0.x (project setup, scaffolding)
3. **When ready for first feature** - Conduct Phase 1 Q&A (read `llm_qa_phase1_questions__t__.md`)
4. **When ready for production** - Conduct Phase 2 Q&A (read `llm_qa_phase2_questions__t__.md`)
5. **If secure Quality** - Conduct Phase 3 Q&A (read `llm_qa_phase3_questions__t__.md`)
