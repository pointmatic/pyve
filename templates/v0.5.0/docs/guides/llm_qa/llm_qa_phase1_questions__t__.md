# Phase 1: Core Technical Questions

## Overview

**Phase:** 1 (Core Technical)  
**When:** Before implementing first major feature (v0.1.0)  
**Duration:** 15-30 minutes  
**Questions:** 10-25 (varies by Quality level)  
**Outcome:** Technical foundation for feature development

**Before starting:** Read `llm_qa_principles__t__.md` to understand Q&A methodology.

## Topics Covered

- Architecture (system boundaries, components, data flow, dependencies, scalability)
- Technical stack (libraries, database, API type, build tools)
- Development workflow (testing, linting, dependencies, CI/CD)

## Question Templates

### Architecture (Required for prototype/production/secure)

**Context:** Understanding the system architecture helps ensure components work together and scale appropriately.

---

**Question 1: System Boundaries** (skip for experiment)
```
What are the main boundaries of your system?

Think about:
- What's inside your system vs external dependencies?
- What services/APIs will you integrate with?
- What data flows in and out?

Example: "My system: Web API + PostgreSQL database. External: Stripe for payments, SendGrid for email. Data: Users submit forms, we store in DB, send confirmation emails."

System boundaries: ___________
```

**Fills:** `docs/specs/technical_design_spec.md` (Architecture section)

---

**Question 2: Key Components** (prototype/production/secure)
```
What are the major components or modules in your system?

For a web app: frontend, API, database, background workers
For a CLI tool: parser, processor, output formatter
For a library: core module, utilities, integrations

Example: "Web frontend (React), REST API (FastAPI), PostgreSQL database, Redis cache, Celery workers for async tasks"

Components: ___________
```

**Fills:** `docs/specs/technical_design_spec.md` (Components section), `docs/specs/codebase_spec.md` (Components section)

---

**Question 3: Data Flow** (production/secure only)
```
How does data flow through your system?

Describe the path from input to output, including any transformations or storage.

Example: "User uploads CSV → Parse rows → Validate data → Store in PostgreSQL → Generate report → Return PDF"

Data flow: ___________
```

**Fills:** `docs/specs/technical_design_spec.md` (Architecture section)

---

**Question 4: External Dependencies** (prototype/production/secure)
```
What external services or APIs will you depend on?

Examples:
- Databases (PostgreSQL, MongoDB, Redis)
- APIs (Stripe, Twilio, OpenAI)
- Cloud services (S3, CloudWatch)
- Authentication (Auth0, Google OAuth)

External dependencies: ___________ (or "none")
```

**Fills:** `docs/specs/technical_design_spec.md` (Components section), `docs/specs/codebase_spec.md` (Dependencies section)

---

**Question 5: Scalability Needs** (production/secure only)
```
What are your scalability requirements?

Consider:
- Expected number of users/requests
- Data volume (records, file sizes)
- Geographic distribution
- Growth projections

Example: "Start with 10 users, grow to 100 in 6 months. Single region (US). Data: ~1GB total, 10K records."

Scalability needs: ___________
```

**Fills:** `docs/specs/technical_design_spec.md` (Performance & Scalability section)

---

### Technical Stack (Required for all non-experiment)

**Context:** Choosing the right libraries and tools upfront prevents costly rewrites later.

---

**Question 6: Key Libraries** (prototype/production/secure)
```
What major libraries or packages will you use?

For Python web apps: Flask/FastAPI, SQLAlchemy, Pydantic, etc.
For CLI tools: Click/Typer, Rich (formatting), etc.
For data processing: Pandas, NumPy, etc.

Example: "FastAPI (web framework), SQLAlchemy (ORM), Pydantic (validation), pytest (testing)"

Key libraries: ___________
```

**Fills:** `docs/specs/implementation_options_spec.md` (Frameworks section), `docs/specs/codebase_spec.md` (Dependencies section)

---

**Question 7: Database/Storage** (if applicable)
```
Will you need a database or persistent storage?

Options:
- **None**: In-memory only, no persistence
- **File-based**: SQLite, JSON files, CSV
- **Relational**: PostgreSQL, MySQL
- **NoSQL**: MongoDB, Redis, DynamoDB
- **Object storage**: S3, GCS, local filesystem

Example: "PostgreSQL for structured data, Redis for caching, S3 for file uploads"

Storage: ___________ (or "none")
```

**Fills:** `docs/specs/implementation_options_spec.md` (Data & State section), `docs/specs/technical_design_spec.md` (Data Model section)

---

**Question 8: API/Interface Type** (if applicable)
```
How will users/systems interact with your project?

- **CLI**: Command-line interface with arguments/flags
- **REST API**: HTTP endpoints (GET, POST, etc.)
- **GraphQL**: Flexible query API
- **Web UI**: Browser-based interface
- **Library**: Imported as a package
- **gRPC**: High-performance RPC
- **Other**: [specify]

Example: "REST API with JSON responses, plus a simple web UI for admin tasks"

Interface type: ___________
```

**Fills:** `docs/specs/technical_design_spec.md` (Interfaces section)

---

**Question 9: Build/Package Tools** (prototype/production/secure)
```
What tools will you use for building and packaging?

For Python:
- **pip-tools**: requirements.in → requirements.txt (recommended for apps)
- **poetry**: Modern dependency management
- **hatch**: Fast, standards-based
- **setuptools**: Traditional setup.py

For JavaScript:
- **npm/yarn/pnpm**: Package managers
- **webpack/vite**: Bundlers

Example: "pip-tools for dependency management, setuptools for packaging"

Build tools: ___________
```

**Fills:** `docs/specs/codebase_spec.md` (Build & Packaging section), `docs/specs/implementation_options_spec.md` (Tooling section)

---

### Development Workflow (Required for all non-experiment)

**Context:** Establishing workflow early prevents technical debt and ensures code quality.

---

**Question 10: Testing Approach** (prototype/production/secure)
```
What testing strategy will you use?

For prototype:
- Basic smoke tests (does it run?)
- Manual testing

For production/secure:
- Unit tests (test individual functions)
- Integration tests (test components together)
- End-to-end tests (test full workflows)

Example: "Unit tests with pytest for all business logic, integration tests for API endpoints, manual testing for UI"

Testing approach: ___________

Test framework: ___________ (e.g., pytest, jest, mocha)
```

**Fills:** `docs/specs/technical_design_spec.md` (Testing Strategy section), `docs/specs/codebase_spec.md` (Testing section)

---

**Question 11: Code Quality Tools** (prototype/production/secure)
```
What tools will you use for linting and formatting?

For Python:
- **ruff**: Fast linter + formatter (recommended)
- **black**: Opinionated formatter
- **mypy**: Type checking
- **pylint/flake8**: Traditional linters

For JavaScript:
- **ESLint**: Linting
- **Prettier**: Formatting
- **TypeScript**: Type checking

Example: "ruff for linting and formatting, mypy for type checking"

Code quality tools: ___________
```

**Fills:** `docs/specs/codebase_spec.md` (Linting & Formatting section)

---

**Question 12: Dependency Management** (prototype/production/secure)
```
How will you manage dependencies?

For Python apps (recommended):
- requirements.in (version ranges) → pip-compile → requirements.txt (exact pins + hashes)

For Python libraries:
- pyproject.toml (bounded ranges) + constraints.txt for testing

For JavaScript:
- package.json with lock file (package-lock.json, yarn.lock)

Example: "pip-tools with requirements.in for development, compiled to requirements.txt with hashes"

Dependency approach: ___________
```

**Fills:** `docs/specs/codebase_spec.md` (Dependencies section)

---

**Question 13: CI/CD** (production/secure only)
```
Will you use continuous integration/deployment?

Options:
- **GitHub Actions**: Built into GitHub
- **GitLab CI**: Built into GitLab
- **CircleCI/Travis**: Third-party services
- **None**: Manual testing and deployment

What to automate:
- Run tests on every commit
- Lint/format checks
- Build and deploy (for production)

Example: "GitHub Actions to run tests and linting on every PR, auto-deploy to staging on merge to main"

CI/CD: ___________ (or "none")
```

**Fills:** `docs/specs/codebase_spec.md` (CI/CD section)

---

## Example Q&A Session: Prototype-Level Web App

**LLM:** You've completed Phase 0 (project basics). Now let's fill out the core technical details for Phase 1. This should take about 15-20 minutes. Ready to proceed?

**Developer:** Yes, let's do it.

---

**LLM:** What are the main boundaries of your system? Think about what's inside your system vs external dependencies, and what data flows in and out.

**Developer:** My system will have a web frontend and a backend API. It'll integrate with Stripe for payments and use PostgreSQL to store data. Users will submit orders through the web UI.

---

**LLM:** Got it. What are the major components or modules?

**Developer:** A React frontend, a FastAPI backend, and a PostgreSQL database.

---

**LLM:** What external services or APIs will you depend on?

**Developer:** Stripe for payment processing, and maybe SendGrid for sending email receipts.

---

**LLM:** What major libraries or packages will you use?

**Developer:** For the backend: FastAPI, SQLAlchemy for the database, Pydantic for validation. For the frontend: React, Axios for API calls.

---

**LLM:** You mentioned PostgreSQL. Will you use any other storage like Redis for caching or S3 for files?

**Developer:** Just PostgreSQL for now. I might add Redis later if I need caching.

---

**LLM:** How will users and systems interact with your project?

**Developer:** Users will use a web UI. The frontend will call a REST API with JSON responses.

---

**LLM:** What tools will you use for building and packaging?

**Developer:** For Python, I'll use pip-tools to manage dependencies. For the frontend, npm.

---

**LLM:** What testing strategy will you use?

**Developer:** I want unit tests for the backend business logic using pytest, and some integration tests for the API endpoints. Manual testing for the frontend for now.

---

**LLM:** What tools will you use for linting and formatting?

**Developer:** Ruff for Python linting and formatting, mypy for type checking. ESLint and Prettier for JavaScript.

---

**LLM:** How will you manage dependencies?

**Developer:** For the backend, I'll use pip-tools with requirements.in that compiles to requirements.txt. For the frontend, package.json with package-lock.json.

---

**LLM:** Will you use continuous integration/deployment?

**Developer:** Yes, GitHub Actions. I want it to run tests and linting on every pull request.

---

**LLM:** Perfect! Here's what I understand:

**Architecture:**
- Components: React frontend, FastAPI backend, PostgreSQL database
- External: Stripe (payments), SendGrid (email)
- Data flow: Users submit orders via web UI → API processes → Store in PostgreSQL → Stripe for payment → SendGrid for receipt

**Technical Stack:**
- Backend: FastAPI, SQLAlchemy, Pydantic, pytest
- Frontend: React, Axios
- Database: PostgreSQL
- Build: pip-tools (backend), npm (frontend)

**Development Workflow:**
- Testing: pytest for unit/integration tests, manual for frontend
- Code quality: ruff + mypy (Python), ESLint + Prettier (JavaScript)
- Dependencies: pip-tools with requirements.in → requirements.txt
- CI/CD: GitHub Actions for tests and linting on PRs

Does this look correct?

**Developer:** Yes, that's perfect.

---

**LLM:** Excellent! I've filled out the Phase 1 specifications in:
- `docs/specs/technical_design_spec.md` (Architecture, Components, Data Model, Interfaces, Testing Strategy)
- `docs/specs/codebase_spec.md` (Components, Dependencies, Testing, Linting & Formatting, CI/CD)
- `docs/specs/implementation_options_spec.md` (Frameworks, Data & State, Tooling)

You're ready to start Phase 1 implementation (v0.1.0 - first feature).

Would you like me to:
1. Start implementing v0.1.0 (build the first feature)
2. Review the specs in detail first
3. Ask more questions about production deployment (Phase 2)

**Developer:** Let's start implementing v0.1.0.

---

## Summary: What Gets Filled Out

After Phase 1 Q&A, the following spec sections should be populated:

### `docs/specs/technical_design_spec.md`
- Architecture (system boundaries, high-level diagram, deployment targets)
- Components (major components, responsibilities, interactions)
- Data Model (core entities, schemas, storage engines)
- Interfaces (APIs, CLIs, UIs with key endpoints/commands)
- Performance & Scalability (expected load, scaling strategies)
- Testing Strategy (unit, integration, e2e coverage plans)

### `docs/specs/codebase_spec.md`
- Components (detailed list with paths, entrypoints, audience)
- Dependencies (per component type, update cadence)
- Testing (frameworks, scope, commands, coverage targets)
- Linting & Formatting (tools, commands, enforcement)
- CI/CD (provider, pipelines, matrix, release process)

### `docs/specs/implementation_options_spec.md`
- Frameworks (candidates, considerations, selection)
- Data & State (candidates, considerations, selection)
- Tooling (dependency managers, linters, formatters, test frameworks)

## Next Steps

After completing Phase 1 Q&A:

1. **Review specs with developer** - Confirm technical approach
2. **Start Phase 1 implementation** - v0.1.x (first major feature)
3. **When ready for production** - Conduct Phase 2 Q&A (read `llm_qa_phase2_questions__t__.md`)
4. **If secure Quality** - Conduct Phase 3 Q&A (read `llm_qa_phase3_questions__t__.md`)
