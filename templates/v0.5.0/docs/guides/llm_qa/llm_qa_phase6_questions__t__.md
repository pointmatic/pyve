# Phase 6: Data & Persistence Questions

## Overview

**Phase:** 6 (Data & Persistence)  
**When:** When designing data storage and persistence  
**Duration:** 15-20 minutes  
**Questions:** 5 total  
**Outcome:** Data architecture and persistence strategy defined

**Before starting:** Read `llm_qa_principles__t__.md` to understand Q&A methodology.

**Note:** This phase is optional and can be done as needed based on your project's data requirements.

## Topics Covered

- Database design (schema, relationships, normalization)
- Data migrations
- Backup strategy
- Caching strategy
- Data modeling and validation

## Question Templates

### Question 1: Database Design (Required if using a database)

**Context:** Good database design ensures data integrity and query performance.

```
How will you design your database schema?

Design considerations:
- **Entities**: What are the main data entities? (users, posts, orders, etc.)
- **Relationships**: How do entities relate? (one-to-many, many-to-many)
- **Normalization**: Normalized (3NF) or denormalized for performance?
- **Indexes**: Which fields need indexes for fast queries?
- **Constraints**: Foreign keys, unique constraints, check constraints

Example: "Entities: users, posts, comments. Relationships: user has many posts, post has many comments. Normalized to 3NF. Indexes on user_id, post_id, created_at."

Database design: ___________
```

**Fills:** `docs/specs/technical_design_spec.md` (Data Model section)

---

### Question 2: Data Migrations (Required if using a database)

**Context:** Migrations allow you to evolve your schema safely over time.

```
How will you manage database schema changes?

Migration strategy:
- **Tool**: Alembic (SQLAlchemy), Django migrations, Flyway, Liquibase
- **Versioning**: Sequential version numbers or timestamps
- **Rollback**: Are migrations reversible?
- **Testing**: Test migrations on staging before production
- **Zero-downtime**: Can migrations run while app is serving traffic?

Example: "Alembic for migrations, sequential version numbers, all migrations reversible, test on staging first, design for zero-downtime"

Migration strategy: ___________
```

**Fills:** `docs/specs/technical_design_spec.md` (Data Model section, Rollout & Migration section)

---

### Question 3: Backup Strategy (Required if using a database)

**Context:** Backups protect against data loss from bugs, attacks, or disasters.

```
How will you backup your database?

Backup strategy:
- **Frequency**: How often? (hourly, daily, weekly)
- **Retention**: How long to keep backups? (7 days, 30 days, 1 year)
- **Type**: Full backups or incremental?
- **Storage**: Where stored? (same provider, different region, different provider)
- **Testing**: How often to test restores? (monthly, quarterly)
- **Automation**: Automated or manual?

Example: "Daily full backups via Fly.io, 30-day retention, stored in same region, test restore monthly, fully automated"

Backup strategy: ___________
```

**Fills:** `docs/specs/codebase_spec.md` (Infrastructure section), `docs/specs/technical_design_spec.md` (Data Model section)

---

### Question 4: Caching Strategy (Optional, recommended for production)

**Context:** Caching improves performance by reducing database load.

```
Will you use caching? If so, how?

Caching options:
- **None**: No caching (simplest, but may be slow)
- **Application cache**: In-memory cache (Redis, Memcached)
- **Database cache**: Query result caching
- **CDN cache**: Static assets and pages (Cloudflare, CloudFront)
- **HTTP cache**: Browser and proxy caching (Cache-Control headers)

Caching strategy:
- **What to cache**: Frequently accessed, rarely changing data
- **Cache invalidation**: How to update cache when data changes?
- **TTL**: How long to cache? (seconds, minutes, hours)

Example: "Redis for application cache, cache user profiles (5 min TTL), cache API responses (1 min TTL), invalidate on updates"

Caching: ___________
```

**Fills:** `docs/specs/technical_design_spec.md` (Data Model section, Performance & Scalability section)

---

### Question 5: Data Modeling & Validation (Required if using a database)

**Context:** Data validation ensures data integrity and prevents bugs.

```
How will you model and validate data?

Data modeling:
- **ORM**: SQLAlchemy, Django ORM, Prisma, TypeORM
- **Schema validation**: Pydantic, Marshmallow, Joi, Zod
- **Type safety**: Use type hints/annotations
- **Constraints**: Required fields, min/max values, regex patterns

Validation layers:
- **API layer**: Validate incoming requests
- **Business logic**: Validate business rules
- **Database layer**: Database constraints (NOT NULL, CHECK, etc.)

Example: "SQLAlchemy ORM with Pydantic for validation, type hints throughout, validate at API layer and enforce with database constraints"

Data modeling: ___________
```

**Fills:** `docs/specs/technical_design_spec.md` (Data Model section)

---

## Summary: What Gets Filled Out

After Phase 6 Q&A, the following spec sections should be populated:

### `docs/specs/codebase_spec.md`
- Infrastructure (backup strategy)

### `docs/specs/technical_design_spec.md`
- Data Model (entities, relationships, schema, storage engines, retention, migrations, validation)
- Performance & Scalability (caching strategies)
- Rollout & Migration (database migration strategy)

## Next Steps

After completing Phase 6 Q&A:

1. **Review data architecture with developer** - Confirm database design and strategy
2. **Proceed to other feature-specific phases** (optional):
   - Phase 7: User Interface (read `llm_qa_phase7_questions__t__.md`)
   - Phase 8: API Design (read `llm_qa_phase8_questions__t__.md`)
   - Phase 9: Background Jobs (read `llm_qa_phase9_questions__t__.md`)
   - Phase 10: Analytics & Observability (read `llm_qa_phase10_questions__t__.md`)
3. **Or implement data layer** - Set up database, migrations, backups, caching

**Note:** Phase 6 is optional and can be skipped if your project doesn't require persistent data storage. It can be done at any point when you need to design your data layer.
