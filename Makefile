# Pyve Test Makefile
# Provides convenient targets for running tests

.PHONY: test test-unit test-integration test-integration-ci test-all coverage clean help

# Default target
help:
	@echo "Pyve Test Targets:"
	@echo "  make test                          - Run all tests (unit + integration)"
	@echo "  make test-unit                     - Run only Bats unit tests"
	@echo "  make test-integration              - Run only pytest integration tests"
	@echo "  make test-integration-ci           - Run venv tests with CI=true (simulates CI)"
	@echo "  make test-integration-micromamba-ci - Run micromamba tests with CI=true"
	@echo "  make test-all                      - Run all tests with verbose output"
	@echo "  make coverage                      - Run tests with coverage reporting"
	@echo "  make clean                         - Clean test artifacts"
	@echo ""
	@echo "Requirements:"
	@echo "  - Bats: brew install bats-core (macOS) or sudo apt-get install bats (Linux)"
	@echo "  - pytest: pip install pytest pytest-cov pytest-xdist"

# Run all tests (unit + integration)
test: test-unit test-integration

# Run only Bats unit tests
test-unit:
	@echo "Running Bats unit tests..."
	@if command -v bats >/dev/null 2>&1; then \
		if [ -n "$$(find tests/unit -name '*.bats' 2>/dev/null)" ]; then \
			bats tests/unit/*.bats; \
		else \
			echo "No Bats tests found in tests/unit/"; \
		fi \
	else \
		echo "Error: Bats not installed. Install with:"; \
		echo "  macOS: brew install bats-core"; \
		echo "  Linux: sudo apt-get install bats"; \
		exit 1; \
	fi

# Run only pytest integration tests
test-integration:
	@echo "Running pytest integration tests..."
	@if command -v pytest >/dev/null 2>&1; then \
		if [ -d "tests/integration" ] && [ -n "$$(find tests/integration -name 'test_*.py' 2>/dev/null)" ]; then \
			pytest tests/integration/ -v; \
		else \
			echo "No pytest tests found in tests/integration/"; \
		fi \
	else \
		echo "Error: pytest not installed. Install with:"; \
		echo "  pip install pytest pytest-cov pytest-xdist"; \
		exit 1; \
	fi

# Run integration tests with CI environment (simulates CI locally)
test-integration-ci:
	@echo "Running pytest integration tests in CI mode..."
	@if command -v pytest >/dev/null 2>&1; then \
		if [ -d "tests/integration" ] && [ -n "$$(find tests/integration -name 'test_*.py' 2>/dev/null)" ]; then \
			CI=true pytest tests/integration/ -v -m "venv and not requires_micromamba" --tb=short; \
		else \
			echo "No pytest tests found in tests/integration/"; \
		fi \
	else \
		echo "Error: pytest not installed. Install with:"; \
		echo "  pip install pytest pytest-cov pytest-xdist"; \
		exit 1; \
	fi

# Run micromamba integration tests with CI environment
test-integration-micromamba-ci:
	@echo "Running micromamba integration tests in CI mode..."
	@if command -v pytest >/dev/null 2>&1; then \
		if [ -d "tests/integration" ] && [ -n "$$(find tests/integration -name 'test_*.py' 2>/dev/null)" ]; then \
			CI=true pytest tests/integration/ -v -m "micromamba or requires_micromamba" --tb=short; \
		else \
			echo "No pytest tests found in tests/integration/"; \
		fi \
	else \
		echo "Error: pytest not installed. Install with:"; \
		echo "  pip install pytest pytest-cov pytest-xdist"; \
		exit 1; \
	fi

# Run all tests with verbose output
test-all:
	@echo "Running all tests with verbose output..."
	@$(MAKE) test-unit
	@$(MAKE) test-integration

# Run tests with coverage reporting
coverage:
	@echo "Running tests with coverage..."
	@if command -v pytest >/dev/null 2>&1; then \
		if [ -d "tests/integration" ] && [ -n "$$(find tests/integration -name 'test_*.py' 2>/dev/null)" ]; then \
			pytest tests/integration/ --cov=. --cov-report=html --cov-report=term; \
			echo ""; \
			echo "Coverage report generated: htmlcov/index.html"; \
		else \
			echo "No pytest tests found in tests/integration/"; \
		fi \
	else \
		echo "Error: pytest not installed. Install with:"; \
		echo "  pip install pytest pytest-cov pytest-xdist"; \
		exit 1; \
	fi

# Clean test artifacts
clean:
	@echo "Cleaning test artifacts..."
	@rm -rf .pytest_cache htmlcov .coverage
	@find . -type d -name __pycache__ -exec rm -rf {} + 2>/dev/null || true
	@echo "Test artifacts cleaned."
