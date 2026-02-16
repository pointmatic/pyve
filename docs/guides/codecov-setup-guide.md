# Codecov Setup Guide

This guide explains how to set up Codecov integration for the Pyve project.

## Prerequisites

- Repository must be on GitHub
- Codecov account (free for open source)

## Important: Public vs Private Repositories

**For Public Repositories (like pyve):**
- ✅ **No token required!** Codecov uses GitHub's OIDC authentication automatically
- The workflow is already configured to work without a token
- Simply add the repository to your Codecov account and it will start receiving coverage data

**For Private Repositories:**
- 🔑 Token is required
- Follow the "Add Token to GitHub Secrets" section below

## Setup Steps (Public Repository)

### 1. Create Codecov Account

1. Go to [codecov.io](https://codecov.io)
2. Sign in with your GitHub account
3. Authorize Codecov to access your repositories

### 2. Add Repository to Codecov

1. In Codecov dashboard, click "Add new repository"
2. Find and select `pointmatic/pyve`
3. That's it! No token needed for public repos.

### 3. Verify Setup

After adding the repository:

1. Push a commit to trigger the GitHub Actions workflow
2. Wait for tests to complete
3. Check the Actions tab for successful codecov uploads
4. Visit `https://codecov.io/gh/pointmatic/pyve` to see coverage reports
5. The README badge should now show coverage percentage instead of "unknown"

## Setup Steps (Private Repository Only)

### Add Token to GitHub Secrets

Only needed if the repository is private:

1. In Codecov dashboard, get the upload token for your repository
2. Go to your GitHub repository: `https://github.com/pointmatic/pyve`
3. Navigate to **Settings** → **Secrets and variables** → **Actions**
4. Click **New repository secret**
5. Name: `CODECOV_TOKEN`
6. Value: Paste the token from Codecov dashboard
7. Click **Add secret**

## Configuration

The repository includes a `codecov.yml` configuration file with:

- **Target coverage**: 80%
- **Precision**: 2 decimal places
- **Ignored paths**: tests/, docs/, __pycache__/
- **Flags**: `bash` — scoped to `lib/` and `pyve.sh`, with `carryforward: true`
- **Comment behavior**: Posts coverage reports on PRs

## Troubleshooting

### Badge shows "unknown"

- Verify `CODECOV_TOKEN` is set in GitHub Secrets (required even for public repos with v4 action)
- Check GitHub Actions logs for upload errors
- Ensure kcov is producing `coverage-kcov/kcov-merged/cobertura.xml` (Bash coverage)
- Verify codecov-action@v4 is running successfully in the `bash-coverage` job

### Upload fails

- Check that the token is correct (no extra spaces)
- Verify the repository is added to your Codecov account
- Check GitHub Actions logs for specific error messages

### Coverage not updating

- **Bash coverage**: Ensure the `bash-coverage` CI job ran successfully; check that kcov output exists under `coverage-kcov/`
- **Local**: Run `make coverage-kcov` and check `coverage-kcov/kcov-merged/index.html`
- Check that the codecov upload step runs after test execution

## Coverage Reports

Coverage is tracked separately for:

- **Bash coverage (kcov)**: `lib/*.sh` and `pyve.sh` line coverage from Bats unit tests and pytest integration tests, uploaded with the `bash` flag
- **Integration tests (venv)**: Python test helper coverage across multiple OS and Python versions
- **Integration tests (micromamba)**: Python 3.11 on multiple OS

The primary coverage metric is **Bash line coverage** via kcov, since Pyve is a Bash project. Python-only coverage from `pytest-cov` measures the test helpers, not the code under test.

View detailed reports at: `https://codecov.io/gh/pointmatic/pyve`

## Local Coverage

To generate coverage reports locally:

```bash
# Bash line coverage via kcov (requires: brew install kcov)
make coverage-kcov
open coverage-kcov/kcov-merged/index.html

# Python test helper coverage only (not the code under test)
pytest tests/integration/ --cov=tests/integration --cov-report=html --cov-report=term
open htmlcov/index.html
```

## References

- [Codecov Documentation](https://docs.codecov.com/)
- [codecov-action GitHub](https://github.com/codecov/codecov-action)
- [kcov — Bash/Python/compiled coverage](https://github.com/SimonKagstrom/kcov)
- [Coverage.py Documentation](https://coverage.readthedocs.io/)
