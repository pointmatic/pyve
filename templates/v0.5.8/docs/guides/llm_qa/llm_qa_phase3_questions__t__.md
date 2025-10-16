# Phase 3: Authentication & Authorization Questions

## Overview

**Phase:** 3 (Authentication & Authorization)  
**When:** Before deploying to production  
**Duration:** 15-20 minutes  
**Questions:** 6 total  
**Outcome:** Authentication and authorization strategy defined

**Before starting:** Read `llm_qa_principles__t__.md` to understand Q&A methodology.

## Topics Covered

- Authentication methods (OAuth, passwords, magic links, API keys)
- Session management
- Multi-factor authentication (basic)
- Authorization models (RBAC, permissions)
- Resource-level access control

## Question Templates

### Question 1: Authentication Method (Required for production/secure)

**Context:** How users prove their identity determines security and user experience.

```
How will users authenticate (prove who they are)?

Options:
- **None**: No authentication (public app)
- **Username/password**: Traditional login
- **OAuth**: Login with Google, GitHub, etc. (recommended)
- **Magic links**: Email-based passwordless login
- **API keys**: For API access
- **SSO**: Enterprise single sign-on (SAML, OIDC)

Providers by use case:
- **Google**: Most common, trusted by users
- **GitHub**: Developer tools, technical products
- **Microsoft**: Enterprise applications
- **Auth0/Supabase**: Multi-provider support, managed service

Example: "OAuth with Google for user login, API keys for programmatic access"

Authentication: ___________
```

**Fills:** `docs/specs/security_spec.md` (Authentication section), `docs/specs/technical_design_spec.md` (Security & Privacy section)

---

### Question 2: Session Management (Required if using sessions)

**Context:** Proper session management prevents unauthorized access and session hijacking.

```
How will you manage user sessions?

Session configuration:
- **Session storage**: Server-side (Redis, database) or client-side (JWT)
- **Session timeout**: Inactivity timeout (e.g., 30 minutes)
- **Maximum duration**: Absolute timeout (e.g., 24 hours)
- **Cookie settings**: Secure, HttpOnly, SameSite flags

Example: "Server-side sessions in Redis, 30-minute inactivity timeout, 24-hour max duration, secure cookies with HttpOnly and SameSite=Lax"

Session management: ___________
```

**Fills:** `docs/specs/security_spec.md` (Session Management section)

---

### Question 3: Multi-Factor Authentication (Optional for production, required for secure)

**Context:** MFA significantly reduces account takeover risk.

```
Will you implement multi-factor authentication (MFA)?

MFA options:
- **None**: No MFA (not recommended for production)
- **Optional**: Users can enable MFA
- **Required for admins**: Admins must use MFA
- **Required for all**: All users must use MFA

MFA methods:
- **TOTP**: Time-based one-time passwords (Google Authenticator, Authy)
- **SMS**: Text message codes (less secure but convenient)
- **Email**: Email codes (backup method)
- **Hardware keys**: FIDO2/WebAuthn (most secure)

Example: "Optional MFA for all users, required for admin accounts. Support TOTP and SMS."

MFA: ___________
```

**Fills:** `docs/specs/security_spec.md` (Multi-Factor Authentication section)

---

### Question 4: Authorization Model (Required for production/secure)

**Context:** Authorization controls what authenticated users can do.

```
How will you control what authenticated users can do?

Options:
- **None**: All users have same permissions
- **Role-based (RBAC)**: Users have roles (admin, user, viewer)
- **Permission-based**: Fine-grained permissions per action
- **Resource-level**: Users own specific resources
- **Attribute-based (ABAC)**: Complex rules based on attributes

Example: "RBAC with three roles: admin (full access), editor (create/edit), viewer (read-only)"

Authorization: ___________
```

**Fills:** `docs/specs/security_spec.md` (Authorization section)

---

### Question 5: Role/Permission Definitions (Required if using RBAC/permissions)

**Context:** Clearly defined roles prevent privilege escalation and confusion.

```
What roles or permissions will you define?

For RBAC, define roles:
- **Admin**: Full access, user management
- **Editor/User**: Standard access, create/edit own resources
- **Viewer**: Read-only access
- **Custom roles**: Specific to your application

For permission-based, define key permissions:
- Resource actions (create, read, update, delete)
- Admin actions (user management, settings)
- Special permissions (export data, approve content)

Example: "Roles: admin (all permissions), editor (create/edit posts, manage own profile), viewer (read posts). Permissions: posts.create, posts.edit, posts.delete, users.manage"

Roles/Permissions: ___________
```

**Fills:** `docs/specs/security_spec.md` (Authorization section)

---

### Question 6: Resource-Level Access Control (Required if users own resources)

**Context:** Resource-level access ensures users can only access their own data.

```
How will you control access to specific resources?

Strategies:
- **Ownership**: Users can only access resources they created
- **Sharing**: Resources can be shared with specific users
- **Team-based**: Resources belong to teams/organizations
- **Public/Private**: Resources have visibility settings

Example: "Posts are owned by users. Users can edit/delete their own posts. Admins can edit/delete any post. Posts can be public or private."

Resource access: ___________
```

**Fills:** `docs/specs/security_spec.md` (Authorization section)

---

## Summary: What Gets Filled Out

After Phase 3 Q&A, the following spec sections should be populated:

### `docs/specs/security_spec.md`
- Authentication Requirements (methods, providers, flows)
- Session Management (storage, timeouts, cookie settings)
- Multi-Factor Authentication (requirements, methods)
- Authorization Requirements (model, roles, permissions, resource access)

### `docs/specs/technical_design_spec.md`
- Security & Privacy (authentication and authorization approach)

## Next Steps

After completing Phase 3 Q&A:

1. **Review auth specs with developer** - Confirm authentication and authorization approach
2. **Proceed to Phase 4** - Security Basics (read `llm_qa_phase4_questions__t__.md`)
3. **Or implement authentication** - Set up OAuth, sessions, RBAC

**Note:** Phase 3 covers authentication and authorization fundamentals. Advanced security topics (encryption, secrets rotation, pen testing) are covered in later phases.
