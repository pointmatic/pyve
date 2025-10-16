# Codebase Specification

<!-- Phase 0: Project Basics -->
## Repository
- **Name:** Pyve
- **Summary:** Generic Python environment management tool (shell-based) with room for multi-language components.
- **Status:** internal tool
- **Owners/Contacts:** 

<!-- Phase 0: Project Basics -->
## Quality
- Quality Level: experiment | prototype | production | secure
- Guidance (apply based on chosen level):
  - Experiment: speed over rigor; minimal tests; throwaway acceptable.
  - Prototype: validate function/UX; basic error handling; smoke tests.
  - Production: reliability, observability, CI/CD, SLOs, on-call readiness.
  - Secure: threat modeling, hardening, least-privilege, audits/compliance.
- Entry/Exit criteria:
  - Define minimum gates (tests, lint, coverage, reviews, security scans) per level.

<!-- Phase 0: Project Basics (basic) | Phase 1: Core Technical (detailed) -->
## Components
List each deliverable or scriptable unit and its key traits.
- **Name:** 
- **Kind:** application | library | cli | script
- **Language:** shell | python | cpp | ruby | sql | other
- **Paths:** e.g., `scripts/`, `src/`, top-level utilities
- **Entrypoints/Commands:** e.g., `./pyve.sh --help`
- **Audience:** end-user | internal ops | dev-only

<!-- Phase 0: Project Basics -->
## Runtime & Platforms
- **OS targets:** macOS | Linux
- **CPU/arch:** x86_64 | arm64
- **Language runtimes/toolchains:** Python (versions), Bash/Zsh, GCC/Clang, Ruby/Node if used

<!-- Phase 0: Project Basics (basic) | Phase 1: Core Technical (detailed) -->
## Build & Packaging
- **Build systems:** none | Make/CMake | setuptools/poetry/hatch | other
- **Artifacts:** none | wheel | binary | container
- **Versioning:** SemVer | date-based; changelog location

<!-- Phase 1: Core Technical -->
## Dependencies (Authoritative: `docs/guides/dependencies_guide.md`)
Define per component type and reference language addenda.
- **Python app:** `requirements.in` → `pip-compile` → `requirements.txt` (hashes). Install from lockfile
- **Python lib:** ranges in `pyproject.toml`; test with `constraints.txt`
- **Shell:** local tools
  - zsh available on macOS; syntax check via `zsh -n pyve.sh`
  - Project validation via smoke tests: `--install`, `--init`, `--purge`, `--version`, `--config`
- **C/C++:** manager (vcpkg/conan/brew/apt), min/max versions
- **Ruby:** bundler/Gemfile policy if applicable
- **SQL:** DB engines and version constraints
- **Update cadence:** routine schedule; audit tools (`pip-audit`, etc.)

<!-- Phase 1: Core Technical -->
## Testing
- **Frameworks:** pytest | gtest | bats | rspec | sql tests
- **Scope:** unit | integration | e2e
- **Commands:** how to run locally and in CI
- **Coverage targets:** if applicable; test data locations

<!-- Phase 1: Core Technical -->
## Linting & Formatting
- **Tools:** ruff/black/mypy | clang-format/clang-tidy | shellcheck/shfmt | rubocop | sqlfluff
- **Commands:** enforcement via pre-commit | CI-only

<!-- Phase 2: Production Readiness | Phase 3: Secure/Compliance -->
## Security
- **Secrets:** handling locally/CI
- **Permissions:** least-privilege policy
- **Supply chain:** lockfiles, hashes, SBOM (optional), signing
- **Audits:** cadence/tools

<!-- Phase 1: Core Technical (production/secure) | Phase 2: Production Readiness -->
## CI/CD
- **Provider:** GitHub Actions | other
- **Pipelines:** lint | test | build | release
- **Matrix:** OS/arch/language versions
- **Release process:** manual | tag-driven; artifacts

<!-- Phase 2: Production Readiness -->
## Configuration
- **Mechanisms:** env vars | .env | config files | CLI flags
- **Key variables:** names and meaning

<!-- Phase 0: Project Basics (deployment decision) | Phase 2: Production Readiness (details) -->
## Infrastructure (if deployed)
- **Provider:** Fly.io | AWS | GCP | Azure | Heroku | on-prem | Kubernetes | none
- **Regions/Zones:** deployment locations and failover strategy
- **IaC:** Terraform/Pulumi/CloudFormation location and state management (e.g., `infra/`, remote state)
- **Platform config:** fly.toml, app.yaml, Dockerfile/Containerfile (Podman), docker-compose.yml/podman-compose.yml, k8s manifests location
- **Container runtime:** Docker | Podman (free and open alternative) | other
- **Base images:** Alpine Linux (minimal, uses `ash` shell) | Ubuntu | Debian | distroless | other
- **Secrets:** how/where secrets are stored and accessed (env vars, secret manager, vault)
- **Scaling:** current configuration (instances, resources) and auto-scaling policies
- **Monitoring:** dashboards, alerts, log aggregation (CloudWatch, Stackdriver, Grafana)
- **Cost tracking:** budget alerts, cost allocation tags, optimization strategies
- **Disaster recovery:** backup strategy, RTO/RPO targets, runbook location
- **Access control:** who can deploy, admin access, audit logging

<!-- Phase 2: Production Readiness -->
## Observability
- **Logging:** format/levels (if applicable)
- **Metrics/Tracing:** none (by default)
- **CLI output:** style conventions

## Open Questions / Deferred Topics
- Short list to be fleshed out later

## Language Addenda
- **Python:** `docs/specs/lang/python_spec.md`
- **Shell:** `docs/specs/lang/shell_spec.md`
- Others as needed: `docs/specs/lang/cpp_spec.md`, `docs/specs/lang/ruby_spec.md`, `docs/specs/lang/sql_spec.md`
