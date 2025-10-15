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

#### Foundation Phases (Required for All)

**`llm_qa_phase0_questions__t__.md`** - Project Basics (10 questions)
- Quality level selection, project overview, language/framework, component structure, repository basics
- Example Q&A session (experiment-level CLI tool)

**`llm_qa_phase1_questions__t__.md`** - Core Technical (13 questions)
- Architecture, technical stack, development workflow
- Example Q&A session (prototype-level web app)

#### Production Readiness Phases (Required for production/secure)

**`llm_qa_phase2_questions__t__.md`** - Infrastructure (6 questions)
- Hosting platform, regions/availability, scaling, monitoring, cost, IaC

**`llm_qa_phase3_questions__t__.md`** - Authentication & Authorization (6 questions)
- Auth methods, session management, MFA, RBAC, permissions, resource access

**`llm_qa_phase4_questions__t__.md`** - Security Basics (5 questions)
- Secrets management, encryption, input validation, rate limiting, security auditing

**`llm_qa_phase5_questions__t__.md`** - Operations (8 questions)
- Deployment, health checks, rollback, logging, incidents, backup, config, performance monitoring

#### Feature-Specific Phases (Optional, as needed)

**`llm_qa_phase6_questions__t__.md`** - Data & Persistence (5 questions)
- Database design, migrations, backups, caching, data modeling

**`llm_qa_phase7_questions__t__.md`** - User Interface (6 questions)
- Frontend framework, component architecture, state management, accessibility, responsive design, UI performance

**`llm_qa_phase8_questions__t__.md`** - API Design (5 questions)
- API style, versioning, documentation, rate limiting, webhooks

**`llm_qa_phase9_questions__t__.md`** - Background Jobs (5 questions)
- Job queues, worker architecture, scheduling, retry logic, monitoring

**`llm_qa_phase10_questions__t__.md`** - Analytics & Observability (5 questions)
- Business analytics, application metrics, tracing, alerting, dashboards

#### Secure/Compliance Phases (Required for secure Quality only)

**`llm_qa_phase11_questions__t__.md`** - Threat Modeling (3 questions)
- Threat identification, attack surfaces, mitigations

**`llm_qa_phase12_questions__t__.md`** - Compliance Requirements (5 questions)
- GDPR, HIPAA, PCI DSS, SOC 2, applicable regulations

**`llm_qa_phase13_questions__t__.md`** - Advanced Security (5 questions)
- Advanced encryption, secrets rotation, vulnerability management, pen testing, security training

**`llm_qa_phase14_questions__t__.md`** - Audit Logging (2 questions)
- Audit log requirements, retention policy

**`llm_qa_phase15_questions__t__.md`** - Incident Response (4 questions)
- IR team, incident classification, procedures, breach notification

**`llm_qa_phase16_questions__t__.md`** - Security Governance (4 questions)
- Security policies, risk assessment, vendor management, metrics

## Reading Flow

### General Pattern (All Phases)

1. Read `llm_qa_principles__t__.md` to understand the Q&A approach (first time only)
2. Read the specific phase question file (e.g., `llm_qa_phase2_questions__t__.md`)
3. Conduct Q&A for that phase (10-30 minutes depending on phase)
4. Fill out relevant specs in `docs/specs/` as you go
5. Confirm with developer before proceeding to next phase or implementation

**Token load per phase:** ~200-400 lines (~6-12K tokens) vs ~1600-2000 lines (~60-80K tokens) for monolithic approach

## Quick Reference

### Foundation Phases (All Projects)
| Phase | Name | When | Duration | Questions |
|-------|------|------|----------|-----------|
| **0** | Project Basics | After `pyve --init` | 5-10 min | 10 |
| **1** | Core Technical | Before v0.1.0 | 15-20 min | 13 |

### Production Readiness Phases (production/secure Quality)
| Phase | Name | When | Duration | Questions |
|-------|------|------|----------|-----------|
| **2** | Infrastructure | Before production | 15-20 min | 6 |
| **3** | Auth & Authz | Before production | 15-20 min | 6 |
| **4** | Security Basics | Before production | 15-20 min | 5 |
| **5** | Operations | Before production | 20-25 min | 8 |

### Feature-Specific Phases (As Needed)
| Phase | Name | When | Duration | Questions |
|-------|------|------|----------|-----------|
| **6** | Data & Persistence | When designing data layer | 15-20 min | 5 |
| **7** | User Interface | When building UI | 15-20 min | 6 |
| **8** | API Design | When designing API | 15-20 min | 5 |
| **9** | Background Jobs | When adding workers | 15-20 min | 5 |
| **10** | Analytics & Observability | When adding analytics | 15-20 min | 5 |

### Secure/Compliance Phases (secure Quality Only)
| Phase | Name | When | Duration | Questions |
|-------|------|------|----------|-----------|
| **11** | Threat Modeling | For secure Quality | 15-20 min | 3 |
| **12** | Compliance | For secure Quality | 20-30 min | 5 |
| **13** | Advanced Security | For secure Quality | 20-25 min | 5 |
| **14** | Audit Logging | For secure Quality | 10-15 min | 2 |
| **15** | Incident Response | For secure Quality | 15-20 min | 4 |
| **16** | Security Governance | For secure Quality | 15-20 min | 4 |

### Quality Level Mapping
- **experiment**: Phases 0-1
- **prototype**: Phases 0-1, 6-7 (as needed)
- **production**: Phases 0-7 (core), 8-10 (as needed)
- **secure**: Phases 0-16 (all)

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

By splitting into 17 focused phase files, LLMs can load only what they need:

- **Old monolithic approach:** 1600-2000 lines (~60-80K tokens) for all phases
- **New modular approach:** 200-400 lines (~6-12K tokens) per phase

**Savings:** 80-90% reduction in token load per Q&A session

**Example:** For a production-level web app:
- Old approach: Load all phases (~80K tokens)
- New approach: Load Phases 0,1,2,3,4,5,6,7 individually (~8 sessions × 10K tokens = ~80K total, but spread across multiple sessions)
- Benefit: Never load more than ~12K tokens at once, can pause/resume between phases
