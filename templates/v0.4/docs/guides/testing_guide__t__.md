# Testing Guide

This document outlines testing strategies and how to apply them during development.

## Strategies
- **Minimal**
  - No testing framework.
  - Ad hoc spot testing of features (run scripts/commands manually).
  - Pros: fastest startup; Cons: low confidence, harder regression control.
- **Moderate**
  - Maintain a small suite of functional tests (script or lightweight framework).
  - Target key features and happy paths; add tests for edge cases as they appear.
  - Pros: balanced effort; Cons: potential gaps in coverage.
- **Complete**
  - Full testing framework and plan (e.g., `pytest`).
  - Unit tests planned in `docs/specs/technical_design_spec.md` and implemented before advancing out of a phase.
  - Include CI integration, coverage targets, and pre-merge gates.

## Recommendations
- Start Minimal in Phase 0, graduate to Moderate during implementation of core flows, and aim for Complete before major milestones.
- Keep tests runnable locally via a single command (e.g., `pytest -q`).
- Use fixtures/sample data in `examples/` to keep tests hermetic.

## Running Tests
- Local: `pytest -q`
- Optionally add `make test` or a small script for common flows.
