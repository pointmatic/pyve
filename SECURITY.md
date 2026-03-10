# Security Policy

## Supported Versions

We actively support the following versions of Pyve with security updates:

| Version | Supported          |
| ------- | ------------------ |
| 1.x.x   | :white_check_mark: |
| < 1.0   | :x:                |

## Reporting a Vulnerability

If you discover a security vulnerability in Pyve, please report it responsibly.

**DO NOT** open a public GitHub issue for security vulnerabilities.

### How to Report

Send an email to: **security@pointmatic.com**

Include in your report:
- Description of the vulnerability
- Steps to reproduce the issue
- Potential impact
- Any suggested fixes (optional)

### What to Expect

- **Initial Response**: We will acknowledge your report within 48 hours
- **Investigation**: We will investigate and assess the severity of the issue
- **Updates**: We will keep you informed of our progress
- **Resolution**: We will work to release a fix as quickly as possible
- **Credit**: We will credit you in the security advisory (unless you prefer to remain anonymous)

### Security Update Process

1. Vulnerability is reported and confirmed
2. Fix is developed and tested
3. Security advisory is published
4. Patched version is released
5. Users are notified via GitHub releases and security advisories

## Security Best Practices for Pyve Users

- **Keep Pyve updated**: Run `brew upgrade pyve` regularly (Homebrew) or `git pull && ./pyve.sh --install` (source)
- **Protect .env files**: Pyve creates `.env` files with `chmod 600` permissions - never change this
- **Review .gitignore**: Ensure `.env` is always in `.gitignore` to prevent committing secrets
- **Use trusted Python sources**: Only use official Python versions from asdf/pyenv
- **Verify installations**: Run `pyve doctor` to check environment health

## Known Security Considerations

### Environment Variable Files

Pyve creates `.env` files for storing environment variables. These files:
- Are created with `chmod 600` (owner read/write only)
- Are automatically added to `.gitignore`
- Should **never** contain production secrets in development environments

### Virtual Environment Isolation

Pyve-managed virtual environments:
- Are isolated from system Python
- Do not have access to system site-packages by default
- Should be recreated (`pyve --purge && pyve --init`) if compromised

### Dependency Management

- Pyve automatically upgrades pip to the latest version for security
- Users are responsible for managing their own project dependencies
- Use `pip-audit` or similar tools to scan for vulnerable dependencies

## Disclosure Policy

- Security vulnerabilities will be disclosed publicly only after a fix is available
- We follow responsible disclosure practices
- Critical vulnerabilities may result in immediate patch releases

## Contact

For security-related questions or concerns:
- Email: security@pointmatic.com
- GitHub Security Advisories: https://github.com/pointmatic/pyve/security/advisories

Thank you for helping keep Pyve and its users secure!
