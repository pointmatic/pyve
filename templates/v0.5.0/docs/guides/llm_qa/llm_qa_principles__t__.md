# LLM Q&A Principles

## Purpose

This guide explains how LLMs should conduct structured Q&A sessions with developers to fill out project specifications. Use this as your reference for Q&A methodology, then read the appropriate phase-specific question file.

## Q&A Principles

### 1. Progressive Disclosure
Don't ask everything upfront. Use a phased approach:
- **Project Context:** Establish "who, what, why, when, where" (recommended for all, especially new projects)
- **Phase 0:** Project basics (required for all projects)
- **Phase 1:** Core technical details (required before first feature)
- **Phase 2-5:** Production readiness (required for production Quality)
- **Phase 6-10:** Feature-specific (as needed)
- **Phase 11-16:** Security & compliance (required for secure Quality)

### 2. Quality-Aware Questioning
Adjust question depth and quantity based on Quality level:
- **Experiment:** Minimal questions, focus on speed
- **Prototype:** Basic questions, validate approach
- **Production:** Comprehensive questions, ensure reliability
- **Secure:** Exhaustive questions, verify compliance

### 3. Provide Context and Examples
Before each question:
- Explain why you're asking
- Provide concrete examples
- Offer sensible defaults when appropriate

### 4. Confirm Understanding
After each section:
- Summarize what you learned
- Ask for confirmation
- Allow corrections before moving on

### 5. Support Iteration
- Allow "I don't know yet" responses (mark for later)
- Support "use defaults" for non-critical sections
- Enable returning to update answers as project evolves

## Phase Definitions

### Project Context Phase
**When:** Before Phase 0 (first step for new projects)  
**Duration:** 10-20 minutes  
**Questions:** 8 questions  
**Outcome:** `docs/context/project_context.md` with business/organizational context and Quality level recommendation

**Topics:**
- Problem statement and stakeholders
- Success criteria and constraints
- Ecosystem and integration context
- Scope boundaries and timeline
- Quality level recommendation

**Read:** `project_context_questions__t__.md`

**Philosophy:** Design thinking approach - understand the problem space before jumping to solutions. Answers "who, what, why, when, where" before diving into technical "how."

### Phase 0: Project Basics
**When:** Immediately after `pyve --init`  
**Duration:** 5-10 minutes  
**Questions:** 5-10 total  
**Outcome:** Minimal viable spec to start Phase 0 implementation (v0.0.x)

**Topics:**
- Project overview and purpose
- Quality level selection
- Primary language and framework
- Basic component structure

**Read:** `llm_qa_phase0_questions__t__.md`

### Phase 1: Core Technical
**When:** Before implementing first major feature (v0.1.0)  
**Duration:** 15-30 minutes  
**Questions:** 10-25 (varies by Quality)  
**Outcome:** Technical foundation for feature development

**Topics:**
- Architecture and system boundaries
- Technical stack and key libraries
- Data model basics
- Development workflow (testing, linting, dependencies)

**Read:** `llm_qa_phase1_questions__t__.md`

### Phase 2: Production Readiness
**When:** Before deploying to production  
**Duration:** 30-60 minutes  
**Questions:** 20-40 (varies by Quality)  
**Outcome:** Production-ready specifications

**Topics:**
- Infrastructure and deployment
- Security fundamentals
- Observability and monitoring
- Rollout and migration strategy

**Read:** `llm_qa_phase2_questions__t__.md`

### Phase 3: Secure/Compliance
**When:** For secure Quality level or regulated industries  
**Duration:** 60-120 minutes  
**Questions:** 40-80  
**Outcome:** Compliance-ready specifications

**Topics:**
- Advanced security (threat modeling, hardening)
- Compliance requirements (GDPR, HIPAA, PCI DSS, SOC 2)
- Audit logging and incident response
- Penetration testing and security reviews

**Read:** `llm_qa_phase3_questions__t__.md`

## Quality-Level Intensity Matrix

| Spec Section | Experiment | Prototype | Production | Secure |
|--------------|-----------|-----------|------------|--------|
| **Project Context** | Optional (5 min) | Recommended (10 min) | Recommended (15 min) | Recommended (20 min) |
| **Phase 0: Project Basics** | 5 questions | 6 questions | 8 questions | 10 questions |
| **Phase 1: Architecture** | Skip or 1 | 3-4 questions | 5-7 questions | 8-10 questions |
| **Phase 1: Technical Stack** | 2-3 questions | 4-5 questions | 6-8 questions | 8-10 questions |
| **Phase 1: Development Workflow** | 1-2 questions | 3-4 questions | 5-6 questions | 7-8 questions |
| **Phase 2: Infrastructure** | Skip | Skip or 1 | 6-8 questions | 10-12 questions |
| **Phase 2: Security Basics** | Skip | 1-2 questions | 5-7 questions | 8-10 questions |
| **Phase 2: Operations** | Skip | Skip or 1 | 5-7 questions | 8-10 questions |
| **Phase 3: Advanced Security** | N/A | N/A | N/A | 15-20 questions |
| **Phase 3: Compliance** | N/A | N/A | N/A | 15-25 questions |

## Instructions for LLMs

### Starting a Q&A Session

1. **Greet and explain:**
   ```
   I'll help you fill out the project specifications through a series of questions.
   
   For new projects, we'll start with Project Context (10-20 min) to understand
   the "who, what, why, when, where" before diving into technical details.
   Then we'll cover the technical basics (Phase 0) and expand later as needed.
   
   For existing projects with clear context, we can skip to Phase 0.
   
   Which applies to you?
   ```

2. **Determine current state:**
   - Is this a brand new project? → Start with Project Context, then Phase 0
   - Does the project have partial specs? → Identify gaps and offer to fill them
   - Is the project upgrading Quality level? → Conduct appropriate phase Q&A
   - Is context unclear or missing? → Offer Project Context Q&A

3. **Set expectations:**
   - Tell them how many questions to expect
   - Explain they can say "I don't know yet" or "use defaults"
   - Mention they can update answers later

### Conducting the Q&A

1. **Ask one question at a time** (avoid overwhelming with multiple questions)

2. **Provide context before each question:**
   ```
   To understand your project's scope, I need to know:
   What specific problem does this project solve?
   
   Example: "A CLI tool to merge markdown files for LLM context"
   ```

3. **Offer defaults when appropriate:**
   ```
   What testing framework will you use?
   - For Python: pytest (recommended)
   - For Shell: bats
   - Other: [specify]
   ```

4. **Handle vague answers:**
   - Ask clarifying follow-ups (max 1-2)
   - If still vague, suggest a sensible default
   - Don't get stuck—move forward

5. **Summarize after each section:**
   ```
   Great! Here's what I understand about your project:
   - Purpose: CLI tool to merge markdown files
   - Users: Developers working with LLMs
   - Quality: Prototype (validate functionality)
   - Language: Python 3.11+
   
   Does this look correct?
   ```

### Filling Out Specs

As you gather answers:

1. **Fill specs in real-time** (don't wait until the end)
2. **Use the exact format** from the spec templates
3. **Mark uncertain items** with `<!-- TODO: Confirm with developer -->`
4. **Cross-reference related sections** (e.g., if they mention PostgreSQL, note it in both Data Model and Dependencies)

### Completing the Session

1. **Summarize what was filled out:**
   ```
   I've completed the Phase 0 specifications:
   - docs/specs/codebase_spec.md (Quality, Components, Runtime sections)
   - docs/specs/technical_design_spec.md (Overview, Goals sections)
   - docs/specs/implementation_options_spec.md (Language selection)
   
   You're ready to start Phase 0 implementation (v0.0.x).
   ```

2. **Explain next steps:**
   ```
   When you're ready to implement your first feature (Phase 1), 
   we'll conduct another Q&A session to fill out the architecture 
   and technical stack details.
   ```

3. **Offer to start implementation:**
   ```
   Would you like me to start implementing v0.0.0 (project setup),
   or would you prefer to review the specs first?
   ```

## Handling Special Cases

### "I don't know yet"
```
No problem! I'll mark this section as TODO and we can come back to it later.
For now, I'll use a sensible default: [suggest default]

Does that work, or would you prefer to decide this now?
```

### "Use defaults"
```
I'll use standard defaults for [section]:
- Testing: pytest
- Linting: ruff + mypy
- Formatting: black

These can be changed later. Sound good?
```

### Vague or conflicting answers
```
I want to make sure I understand. You mentioned [X] but also [Y].

Could you clarify: [specific question]?

Or would you like me to suggest an approach based on common patterns?
```

### Scope creep during Q&A
```
That's an interesting feature! To keep us focused, let's capture that as a future enhancement.

I'll add it to the "Open Questions / Deferred Topics" section in the specs.

For now, let's focus on the core functionality: [restate original scope]
```

### Upgrading Quality level
```
You're upgrading from [old level] to [new level]. This means we need to fill out:
- [List of new sections required]

This will take about [X] minutes. Ready to proceed?
```

## Integration with Other Guides

### Relationship to Planning Guide
- **Planning Guide:** Explains how to create technical designs and plan versions
- **Q&A Guide:** Helps gather information to fill out those designs

Use Q&A to populate initial specs, then follow Planning Guide for version planning.

### Relationship to Building Guide
- **Building Guide:** Explains how to implement versions and tick checklists
- **Q&A Guide:** Happens before implementation, during spec creation

Use Q&A to create specs, then follow Building Guide to implement them.

### Relationship to LLM Onramp Guide
- **Onramp Guide:** Entry point for LLMs joining an existing project
- **Q&A Guide:** Entry point for LLMs helping start a new project

For new projects: Project Context Q&A → Phase 0 Q&A → fill specs → Onramp Guide → implement  
For existing projects: Onramp Guide → implement (Q&A only if specs incomplete)

## Tips for Effective Q&A

### Do:
✅ Ask one question at a time  
✅ Provide examples and context  
✅ Offer sensible defaults  
✅ Summarize and confirm understanding  
✅ Fill specs as you go  
✅ Keep sessions short (5-30 minutes per phase)  
✅ Allow "I don't know yet" responses  

### Don't:
❌ Ask everything upfront (use phases)  
❌ Use jargon without explanation  
❌ Get stuck on one question (move forward)  
❌ Skip summarization (confirm understanding)  
❌ Wait until end to fill specs (do it real-time)  
❌ Force decisions on uncertain items (mark as TODO)  

## Next Steps After Q&A

Once Project Context Q&A is complete:

1. **Review `docs/context/project_context.md`** with developer
2. **Proceed to Phase 0 Q&A** (project basics)
3. **Start Phase 0 implementation** (v0.0.x - project setup)
4. **When ready for features,** conduct Phase 1 Q&A
5. **When ready for production,** conduct Phases 2-5 Q&A
6. **If secure Quality,** conduct Phases 11-16 Q&A

Each phase builds on the previous, creating a complete specification incrementally as the project matures. The Project Context serves as the foundation - the "agreement to go and build" that guides all subsequent technical decisions.
