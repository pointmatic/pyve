# Phase 9: Background Jobs Questions

## Overview

**Phase:** 9 (Background Jobs)  
**When:** When adding asynchronous job processing  
**Duration:** 15-20 minutes  
**Questions:** 5 total  
**Outcome:** Background job architecture and strategy defined

**Before starting:** Read `llm_qa_principles__t__.md` to understand Q&A methodology.

**Note:** This phase is optional and can be skipped for projects without background processing needs (synchronous-only applications).

## Topics Covered

- Job queue technology and message brokers
- Worker architecture and scaling
- Job scheduling (cron, recurring jobs)
- Retry logic and failure handling
- Job monitoring and observability

## Question Templates

### Question 1: Job Queue Technology (Required if using background jobs)

**Context:** Job queue technology affects reliability, performance, and operational complexity.

```
What job queue technology will you use?

Options:
- **Redis + Celery** (Python): Popular, feature-rich, battle-tested
  - Pros: Mature, flexible, good monitoring tools
  - Cons: Redis dependency, can be complex to configure
  - Best for: Python apps, complex workflows, scheduling

- **Redis + RQ** (Python): Simpler alternative to Celery
  - Pros: Simpler, easier to get started
  - Cons: Fewer features than Celery
  - Best for: Simple background jobs, Python apps

- **PostgreSQL + pg_boss** (Node.js): Database-backed queue
  - Pros: No additional infrastructure, ACID guarantees
  - Cons: Database load, less performant at scale
  - Best for: Small-medium apps, already using PostgreSQL

- **RabbitMQ**: Dedicated message broker
  - Pros: Reliable, feature-rich, language-agnostic
  - Cons: Additional infrastructure, operational overhead
  - Best for: Microservices, complex routing, high reliability

- **AWS SQS/SNS**: Managed cloud queue
  - Pros: Fully managed, scalable, no ops
  - Cons: Vendor lock-in, cost, latency
  - Best for: AWS deployments, serverless architectures

- **Kafka**: Distributed streaming platform
  - Pros: High throughput, event sourcing, replay
  - Cons: Complex, heavy, overkill for simple jobs
  - Best for: Event streaming, high volume, analytics

Example: "Redis + Celery for Python, supports scheduling and retries, already using Redis for caching"

Job queue: ___________
```

**Fills:** `docs/specs/technical_design_spec.md` (Components section), `docs/specs/implementation_options_spec.md` (Data & State section)

---

### Question 2: Worker Architecture (Required if using background jobs)

**Context:** Worker architecture affects scalability, reliability, and resource utilization.

```
How will you architect your background workers?

Worker configuration:
- **Number of workers**: How many worker processes? (e.g., 2-4 to start)
- **Concurrency**: Threads/processes per worker? (e.g., 4 threads per worker)
- **Queue routing**: Single queue or multiple queues? (e.g., high-priority, low-priority, email)
- **Worker types**: Specialized workers for different job types?

Scaling strategy:
- **Manual**: Fixed number of workers
- **Auto-scaling**: Scale based on queue depth or CPU
- **Serverless**: Lambda/Cloud Functions for each job

Resource limits:
- Memory limits per worker
- CPU limits per worker
- Job timeout limits (e.g., 5 minutes, 1 hour)

Example: "Start with 2 workers, 4 threads each. Separate queues for high-priority and low-priority jobs. Auto-scale up to 10 workers based on queue depth. 30-minute timeout per job."

Worker architecture: ___________
```

**Fills:** `docs/specs/technical_design_spec.md` (Components section), `docs/specs/codebase_spec.md` (Components section)

---

### Question 3: Job Scheduling (Required if using scheduled jobs)

**Context:** Job scheduling enables recurring tasks and time-based automation.

```
Will you need scheduled/recurring jobs?

Scheduling needs:
- **Cron jobs**: Run at specific times (e.g., "daily at 2am", "every hour")
- **Recurring jobs**: Repeat at intervals (e.g., "every 5 minutes")
- **One-time delayed**: Run once after a delay (e.g., "send reminder in 24 hours")

Scheduling tools:
- **Celery Beat**: Built-in scheduler for Celery
- **Cron**: System cron for simple tasks
- **APScheduler**: Python scheduling library
- **Cloud scheduler**: AWS EventBridge, GCP Cloud Scheduler
- **Database-backed**: Store schedule in database, poll for due jobs

Schedule examples:
- "Send daily report at 8am UTC"
- "Clean up old records every Sunday at midnight"
- "Check for updates every 15 minutes"

Example: "Use Celery Beat for scheduling. Daily report at 8am UTC, cleanup every Sunday midnight, health checks every 5 minutes."

Scheduling: ___________ (or "none")
```

**Fills:** `docs/specs/technical_design_spec.md` (Components section, Algorithms / Processing section)

---

### Question 4: Retry Logic (Required if using background jobs)

**Context:** Retry logic ensures transient failures don't cause permanent job failures.

```
How will you handle job failures and retries?

Retry strategy:
- **Max retries**: How many times to retry? (e.g., 3 retries)
- **Backoff**: Exponential backoff or fixed delay? (e.g., 1min, 5min, 15min)
- **Retry conditions**: Retry all failures or only specific errors?
- **Dead letter queue**: Where to send permanently failed jobs?

Failure handling:
- **Logging**: Log all failures with context
- **Alerting**: Alert on repeated failures or dead letter queue growth
- **Manual intervention**: How to retry failed jobs manually?
- **Idempotency**: Ensure jobs can be safely retried

Example: "3 retries with exponential backoff (1min, 5min, 15min). Retry on network errors, don't retry on validation errors. Dead letter queue for permanent failures. Alert if DLQ > 10 jobs."

Retry logic: ___________
```

**Fills:** `docs/specs/technical_design_spec.md` (Error Handling & Resilience section)

---

### Question 5: Job Monitoring (Required for production/secure)

**Context:** Monitoring helps identify bottlenecks, failures, and performance issues.

```
How will you monitor background jobs?

Monitoring needs:
- **Queue depth**: How many jobs waiting? (alert if > threshold)
- **Job duration**: How long do jobs take? (p50, p95, p99)
- **Success/failure rate**: What percentage of jobs succeed?
- **Worker health**: Are workers running? CPU/memory usage?
- **Dead letter queue**: How many permanently failed jobs?

Monitoring tools:
- **Celery Flower**: Web-based monitoring for Celery
- **Custom dashboards**: Grafana, Datadog, New Relic
- **Application logs**: Structured logging with job metadata
- **Alerts**: Slack, PagerDuty, email

Metrics to track:
- Jobs enqueued per minute
- Jobs completed per minute
- Average job duration
- Failed jobs per hour
- Queue depth by queue name

Example: "Use Flower for Celery monitoring. Alert if queue depth > 1000 or failure rate > 5%. Track job duration and throughput in Datadog. Log all job starts/completions."

Job monitoring: ___________
```

**Fills:** `docs/specs/technical_design_spec.md` (Observability section), `docs/specs/codebase_spec.md` (Observability section)

---

## Summary: What Gets Filled Out

After Phase 9 Q&A, the following spec sections should be populated:

### `docs/specs/technical_design_spec.md`
- Components (worker architecture, job queues)
- Algorithms / Processing (job scheduling, workflows)
- Error Handling & Resilience (retry logic, failure handling)
- Observability (job monitoring, metrics)

### `docs/specs/codebase_spec.md`
- Components (worker processes, job handlers)
- Observability (job monitoring tools)

### `docs/specs/implementation_options_spec.md`
- Data & State (job queue technology selection)

## Next Steps

After completing Phase 9 Q&A:

1. **Review background job architecture with developer** - Confirm approach and technology
2. **Proceed to other feature-specific phases** (optional):
   - Phase 10: Analytics & Observability (read `llm_qa_phase10_questions__t__.md`)
3. **Or implement background jobs** - Set up job queue, workers, scheduling, monitoring

**Note:** Phase 9 is optional and can be skipped for projects without background processing needs. It can be done at any point when you need to add asynchronous job processing.
