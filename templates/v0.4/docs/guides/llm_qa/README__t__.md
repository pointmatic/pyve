# LLM Q&A Guides

This directory contains guides for LLMs to conduct structured Q&A sessions with developers to fill out project specifications systematically.

## Purpose

Rather than presenting blank spec templates, LLMs use these guides to ask targeted questions based on the project's Quality level and development phase. This approach:
- Reduces cognitive load (progressive disclosure)
- Ensures completeness (systematic coverage)
- Adapts to project needs (quality-aware questioning)
- Prevents overwhelming users (phased approach)

## When to Use These Guides

- **New projects:** When a developer runs `pyve --init` and needs help filling out `docs/specs/`
- **Spec gaps:** When existing projects have incomplete specifications
- **Quality upgrades:** When moving from experiment → prototype → production → secure

## File Structure

### Core Files (Read These First)

**`llm_qa_principles__t__.md`** - How to conduct Q&A sessions
- Q&A principles (progressive disclosure, quality-aware, context/examples)
- Phase definitions (when to use each phase)
- Quality-level intensity matrix
- Instructions for LLMs (starting, conducting, completing sessions)
- Special case handling
- Integration with other guides

### Question Files (Read Based on Phase)

**`llm_qa_phase0_questions__t__.md`** - Project basics (5-10 questions)
- Quality level selection
- Project overview (problem, users, success criteria)
- Language and framework
- Component structure
- Repository basics
- Example Q&A session (experiment-level CLI tool)

**`llm_qa_phase1_questions__t__.md`** - Core technical (10-25 questions)
- Architecture (system boundaries, components, data flow)
- Technical stack (libraries, database, API type, build tools)
- Development workflow (testing, linting, dependencies)
- Example Q&A session (prototype-level web app)

**`llm_qa_phase2_questions__t__.md`** - Production readiness (20-40 questions)
- Infrastructure (hosting, scaling, monitoring)
- Security basics (authentication, secrets, encryption)
- Operations (deployment, rollback, incident response)
- Example Q&A session (production-level web API)

**`llm_qa_phase3_questions__t__.md`** - Secure/compliance (40-80 questions)
- Advanced security (threat modeling, hardening, penetration testing)
- Compliance (GDPR, HIPAA, PCI DSS, SOC 2)
- Audit logging and incident response
- Example Q&A session (secure-level healthcare platform)

## Reading Flow

### For New Projects (Phase 0)

1. Read `llm_qa_principles__t__.md` to understand the Q&A approach
2. Read `llm_qa_phase0_questions__t__.md` for questions to ask
3. Conduct Phase 0 Q&A (5-10 minutes)
4. Fill out minimal specs in `docs/specs/`
5. Confirm with developer before starting implementation

**Token load:** ~400-500 lines (~12-15K tokens)

### For Phase 1 (Before First Feature)

1. Read `llm_qa_principles__t__.md` (refresh on principles)
2. Read `llm_qa_phase1_questions__t__.md` for questions to ask
3. Conduct Phase 1 Q&A (15-30 minutes)
4. Fill out core technical specs
5. Confirm with developer before implementing features

**Token load:** ~500-600 lines (~15-18K tokens)

### For Phase 2 (Before Production)

1. Read `llm_qa_principles__t__.md` (refresh on principles)
2. Read `llm_qa_phase2_questions__t__.md` for questions to ask
3. Conduct Phase 2 Q&A (30-60 minutes)
4. Fill out production readiness specs
5. Confirm with developer before deploying

**Token load:** ~600-800 lines (~18-24K tokens)

### For Phase 3 (Secure/Compliance)

1. Read `llm_qa_principles__t__.md` (refresh on principles)
2. Read `llm_qa_phase3_questions__t__.md` for questions to ask
3. Conduct Phase 3 Q&A (60-120 minutes)
4. Fill out security and compliance specs
5. Confirm with developer before proceeding

**Token load:** ~700-1000 lines (~21-30K tokens)

## Quick Reference

| Phase | When | Duration | Questions | Files to Read |
|-------|------|----------|-----------|---------------|
| **Phase 0** | After `pyve --init` | 5-10 min | 5-10 | principles + phase0 |
| **Phase 1** | Before v0.1.0 | 15-30 min | 10-25 | principles + phase1 |
| **Phase 2** | Before production | 30-60 min | 20-40 | principles + phase2 |
| **Phase 3** | For secure Quality | 60-120 min | 40-80 | principles + phase3 |

## Integration with Other Guides

- **LLM Onramp Guide** (`docs/guides/llm_onramp_guide.md`): Entry point for LLMs
  - New projects: Use Q&A guides first, then follow onramp guide
  - Existing projects: Skip Q&A, follow onramp guide directly

- **Planning Guide** (`docs/guides/planning_guide.md`): Version planning workflow
  - Q&A helps populate initial specs
  - Planning guide helps structure version progression

- **Building Guide** (`docs/guides/building_guide.md`): Implementation workflow
  - Q&A happens before implementation
  - Building guide governs implementation process

## Tips for LLMs

### Do:
✅ Read only the files you need (principles + current phase)  
✅ Ask one question at a time  
✅ Provide examples and context  
✅ Offer sensible defaults  
✅ Summarize and confirm understanding  
✅ Fill specs as you go (real-time)  

### Don't:
❌ Read all phase files at once (unnecessary token load)  
❌ Ask all questions upfront (use progressive disclosure)  
❌ Use jargon without explanation  
❌ Get stuck on one question (move forward with defaults)  
❌ Wait until end to fill specs (do it incrementally)  

## Token Efficiency

By splitting into separate files, LLMs can load only what they need:

- **Monolithic approach:** 1600-2000 lines (~60-80K tokens) for all phases
- **Modular approach:** 400-1000 lines (~12-30K tokens) per session

**Savings:** 60-70% reduction in token load per Q&A session
