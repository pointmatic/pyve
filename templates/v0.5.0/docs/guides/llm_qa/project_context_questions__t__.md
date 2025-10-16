# Project Context Q&A Questions

## Purpose

Establish project context before technical planning. This phase answers the **who, what, why, when, where** before diving into the **how** (which comes in Phase 0+).

This follows a "design thinking" approach: understand the problem space, stakeholders, constraints, and ecosystem before making technical decisions.

## When to Use

- **New projects:** Before Phase 0 Q&A (first step after `pyve --init`)
- **Existing projects:** When business/organizational context is unclear or has changed
- **Quality upgrades:** When moving to production/secure and need to document context

## Duration

**10-20 minutes** depending on project complexity

## Outcome

Creates `docs/context/project_context.md` with:
- Clear problem statement and goals
- Stakeholder identification
- Success criteria and constraints
- Ecosystem/integration context
- Timeline and scope boundaries
- Recommended Quality level

This document becomes the "agreement to go and build" - the foundation for all technical decisions.

---

## Questions

### 1. Project Vision & Purpose

**Context:** Understanding the fundamental "why" helps guide all technical decisions. This should be clear enough that someone unfamiliar with the project can understand its value in 30 seconds.

**Question:** In 1-3 sentences, what problem does this project solve and for whom?

**Examples:**
- "A CLI tool for developers to merge markdown documentation files into LLM-friendly context bundles, reducing manual copy-paste work."
- "A HIPAA-compliant patient portal for healthcare providers to share lab results and appointment information securely with patients."
- "An internal dashboard for sales teams to visualize pipeline metrics in real-time, replacing manual spreadsheet updates."
- "A personal expense tracker that automatically categorizes transactions and generates monthly budget reports."

**Follow-up questions:**
- What happens today without this solution? (What's the current pain?)
- What's the cost/impact of not solving this problem?
- What does success look like in concrete terms?

**Fills:** `docs/context/project_context.md` → Problem Statement section

---

### 2. Primary Stakeholders

**Context:** Identifying who cares about this project helps prioritize features, understand constraints, and make appropriate trade-offs. Stakeholders include decision makers, users, maintainers, and anyone affected by the project.

**Question:** Who are the key stakeholders for this project?

**Consider:**
- **Decision makers:** Who approves/funds this? Who can say "no"?
- **End users:** Who will actually use this?
- **Maintainers:** Who will support/maintain this long-term?
- **Affected parties:** Who else is impacted (IT, compliance, customers, etc.)?

**Examples:**
- Solo project: "Just me (developer and user)"
- Small team: "Engineering team (5 devs), Product Manager (Jane), CTO (approval)"
- Enterprise: "Sales team (50 users), VP Sales (sponsor), IT Security (compliance), Engineering (maintainers)"

**Follow-up questions:**
- Who has veto power over technical decisions?
- Who will be your primary point of contact for requirements?
- Are there any stakeholders with conflicting interests?

**Fills:** `docs/context/project_context.md` → Stakeholders section

---

### 3. Success Criteria & Metrics

**Context:** Defining measurable success criteria helps determine when the project is "done" and whether it's achieving its goals. This prevents scope creep and provides clear milestones.

**Question:** How will you measure success for this project? What are the key metrics or outcomes?

**Examples:**
- **CLI tool:** "Reduces documentation prep time from 15 minutes to 30 seconds; used by 10+ developers on the team"
- **Patient portal:** "90% of patients access results online (vs calling); HIPAA audit with zero findings"
- **Sales dashboard:** "Sales team checks dashboard daily; forecasting accuracy improves by 20%"
- **Expense tracker:** "I use it consistently for 3 months; monthly budget variance under 10%"

**Consider:**
- **Usage metrics:** Adoption rate, daily/monthly active users
- **Performance metrics:** Speed, uptime, accuracy
- **Business metrics:** Cost savings, revenue impact, time saved
- **Compliance metrics:** Audit results, security incidents
- **Quality metrics:** Bug rate, user satisfaction

**Follow-up questions:**
- What's the minimum viable success? (What must work for v1.0?)
- What would make this project a failure?
- How will you collect/track these metrics?

**Fills:** `docs/context/project_context.md` → Success Criteria section

---

### 4. Constraints & Requirements

**Context:** Understanding constraints early prevents costly rework. Constraints include budget, timeline, compliance, technical limitations, and organizational policies.

**Question:** What are the key constraints or requirements for this project?

**Consider:**
- **Timeline:** Hard deadlines, launch dates, seasonal factors
- **Budget:** Development cost, infrastructure cost, ongoing maintenance
- **Compliance:** HIPAA, GDPR, SOC 2, PCI DSS, industry regulations
- **Technical:** Must integrate with existing systems, language/platform requirements
- **Organizational:** Security policies, approval processes, vendor restrictions
- **Scale:** Expected users, data volume, geographic distribution

**Examples:**
- **Minimal:** "Solo project, no budget, no deadline, no compliance requirements"
- **Startup:** "Launch in 3 months, $20K budget, must scale to 10K users, GDPR compliant"
- **Enterprise:** "Q2 launch (hard deadline), $100K budget, HIPAA + SOC 2 required, must use approved AWS services, 99.9% uptime SLA"

**Follow-up questions:**
- Which constraints are hard (cannot change) vs soft (negotiable)?
- Are there any deal-breakers? (e.g., "Must run on-premise" or "Cannot use cloud services")
- What happens if you miss the deadline or exceed the budget?

**Fills:** `docs/context/project_context.md` → Constraints section

---

### 5. Ecosystem & Integration Context

**Context:** Understanding what already exists helps identify integration points, dependencies, and potential conflicts. This is about the **external environment** the project lives in, not the internal components you're building.

**Question:** What existing systems, services, or tools does this project need to work with or integrate into?

**Consider:**
- **External services:** APIs, SaaS platforms, third-party tools
- **Internal systems:** Databases, authentication systems, existing applications
- **Infrastructure:** Cloud providers, on-premise servers, CI/CD pipelines
- **Tools/platforms:** Development tools, monitoring, deployment platforms
- **Standards/protocols:** REST, GraphQL, OAuth, SAML, etc.

**Examples:**
- **Standalone CLI:** "None - runs locally, no external dependencies"
- **Web app:** "Google OAuth for auth, PostgreSQL database, Stripe for payments, SendGrid for email, deployed on Fly.io"
- **Enterprise integration:** "Must integrate with Salesforce API, Active Directory for auth, existing Oracle database, deploy to internal Kubernetes cluster"
- **Mobile app:** "Firebase for backend, Apple/Google auth, push notifications via FCM/APNS"

**Follow-up questions:**
- Do you have API access/credentials for these systems?
- Are there any integration challenges or limitations you're aware of?
- What data needs to flow between systems?

**Fills:** `docs/context/project_context.md` → Ecosystem section

---

### 6. Scope & Boundaries

**Context:** Clearly defining what's in scope (and explicitly what's out of scope) prevents feature creep and keeps the project focused. This is especially important for v1.0.

**Question:** What's in scope for v1.0, and what's explicitly out of scope?

**Framework:**
- **Must have:** Core features required for launch
- **Should have:** Important but not critical for v1.0
- **Could have:** Nice-to-haves for future versions
- **Won't have:** Explicitly out of scope (at least for v1.0)

**Examples:**
- **CLI tool:**
  - Must: Merge markdown files, preserve formatting, handle nested directories
  - Should: Configuration file support, custom templates
  - Could: Git integration, automatic updates
  - Won't: GUI, web interface, collaborative editing

- **Patient portal:**
  - Must: View lab results, download PDFs, secure login (MFA)
  - Should: Appointment scheduling, prescription refills
  - Could: Telemedicine video calls, health tracking
  - Won't: Provider-to-provider messaging, billing/insurance

**Follow-up questions:**
- What's the minimum feature set for v1.0 to be useful?
- Are there any features that stakeholders expect but you want to defer?
- What's the plan for handling scope creep requests?

**Fills:** `docs/context/project_context.md` → Scope section

---

### 7. Timeline & Milestones

**Context:** Understanding the timeline helps prioritize work, set expectations, and determine the appropriate Quality level. Aggressive timelines may require experiment/prototype Quality, while longer timelines allow for production/secure Quality.

**Question:** What's the target timeline and key milestones?

**Consider:**
- **Start date:** When does development begin?
- **Key milestones:** Phase 0 complete, Phase 1 complete, beta launch, v1.0 launch
- **Hard deadlines:** Regulatory deadlines, market events, contract obligations
- **Ongoing:** Maintenance, feature releases, support

**Examples:**
- **Personal project:** "No hard deadline, work on it weekends, hope to launch in 3-6 months"
- **Startup MVP:** "Start now, Phase 0 in 1 week, Phase 1 in 4 weeks, beta in 8 weeks, v1.0 in 12 weeks"
- **Enterprise project:** "Q1: Planning & Phase 0, Q2: Phase 1 development, Q3: Testing & security review, Q4: Production launch"

**Follow-up questions:**
- Are these deadlines flexible or fixed?
- What happens if you slip the schedule?
- What's the plan after v1.0 launch? (Maintenance, new features, sunsetting?)

**Fills:** `docs/context/project_context.md` → Timeline section

---

### 8. Quality Level Recommendation

**Context:** Based on the previous answers (constraints, compliance, scale, timeline), we can recommend an appropriate Quality level. This determines which Q&A phases are required and how thorough the technical implementation should be.

**Question:** Based on what you've told me, here's my Quality level recommendation. Does this align with your expectations?

**Decision framework:**
- **Experiment:** Solo project, no users, no compliance, rapid prototyping, short-lived
- **Prototype:** Small team, limited users, validate approach, may become production
- **Production:** Real users, uptime matters, security basics, monitoring, backups
- **Secure:** Compliance required (HIPAA, GDPR, SOC 2), sensitive data, audit trails, formal security

**Recommendation logic:**
```
IF compliance_required (HIPAA, GDPR, SOC 2, PCI DSS):
  → Secure Quality (required)

ELSE IF production_users AND (uptime_sla OR sensitive_data OR revenue_generating):
  → Production Quality

ELSE IF validating_approach OR small_team OR limited_users:
  → Prototype Quality

ELSE IF solo_project OR short_lived OR rapid_experimentation:
  → Experiment Quality
```

**Example recommendations:**
- "Based on your HIPAA requirement and 10K users, I recommend **Secure Quality**. This means we'll need to complete all Q&A phases (0-16) and implement comprehensive security controls."
- "Since this is a personal CLI tool with no external users, I recommend **Experiment Quality**. We'll focus on core functionality and skip production/security phases."
- "With 50 internal users and no compliance requirements, I recommend **Production Quality**. We'll implement monitoring, backups, and security basics (Phases 0-5)."

**Follow-up questions:**
- Does this Quality level match your expectations?
- Are there any factors I missed that would change the recommendation?
- Are you comfortable with the trade-offs of this Quality level?

**Fills:** `docs/context/project_context.md` → Quality Level section

---

## Conducting the Q&A Session

### Before Starting

1. **Explain the purpose:**
   ```
   Before we dive into technical details, I'd like to understand the project context.
   This will take about 10-20 minutes and helps ensure we make the right technical
   decisions later. We'll cover who, what, why, when, and where - but not "how" yet.
   
   The outcome will be a Project Context document that serves as our "agreement to
   go and build" - the foundation for all technical work.
   
   Ready to begin?
   ```

2. **Set expectations:**
   - 8 questions total
   - Can say "I don't know yet" (we'll mark as TODO)
   - Can update answers later (living document)
   - Will recommend Quality level at the end

### During the Q&A

1. **Ask one question at a time**
2. **Provide context and examples** before each question
3. **Listen for clues** about constraints, compliance, scale
4. **Summarize** after each section to confirm understanding
5. **Fill `docs/context/project_context.md`** in real-time (don't wait until end)

### After Each Question

Summarize what you learned:
```
Got it! So the problem is [X], and success looks like [Y]. 
This will help us prioritize [Z] in the technical design.
```

### After Completing All Questions

1. **Provide Quality level recommendation** with reasoning
2. **Summarize the full context:**
   ```
   Here's what I understand about your project:
   
   **Problem:** [1-sentence summary]
   **Users:** [primary stakeholders]
   **Success:** [key metric]
   **Constraints:** [top 2-3 constraints]
   **Ecosystem:** [key integrations]
   **Timeline:** [target launch]
   **Quality:** [recommended level]
   
   Does this accurately capture your project context?
   ```

3. **Explain next steps:**
   ```
   I've created docs/context/project_context.md with all of this information.
   
   Next steps:
   - Review the context document (make any corrections)
   - Proceed to Phase 0 Q&A (technical basics: ~10-15 min)
   - Start Phase 0 implementation (v0.0.x - project setup)
   
   Would you like to proceed to Phase 0 Q&A now, or take a break?
   ```

---

## Example Q&A Session 1: Internal Sales Dashboard (Production Quality)

**LLM:** Before we dive into technical details, I'd like to understand the project context. This will take about 10-20 minutes and helps ensure we make the right technical decisions later. Ready to begin?

**User:** Yes, let's do it.

**LLM:** Great! Let's start with the big picture. In 1-3 sentences, what problem does this project solve and for whom?

**User:** Our sales team wastes hours every week manually updating spreadsheets with pipeline data from Salesforce. We need a dashboard that automatically pulls this data and shows key metrics in real-time.

**LLM:** Got it! So the problem is manual data entry taking hours per week, and success looks like automated real-time visibility. This will help us prioritize API integration and refresh frequency in the technical design.

What happens today without this solution? What's the cost of the current manual process?

**User:** Sales reps spend 2-3 hours per week updating spreadsheets instead of selling. Plus, the data is often stale by the time leadership reviews it, so we're making decisions on outdated information.

**LLM:** That's a clear pain point - both time waste and decision quality. Let me capture that.

Next question: Who are the key stakeholders for this project? Consider decision makers, end users, maintainers, and anyone affected.

**User:** End users are the sales team (about 50 people). The VP of Sales (Sarah) is the sponsor and decision maker. Our IT team will need to approve any Salesforce integrations. And our engineering team (5 people) will maintain it long-term.

**LLM:** Perfect. So we have:
- **Users:** Sales team (50 people)
- **Sponsor/Decision maker:** VP Sales (Sarah)
- **Approval required:** IT team (Salesforce integration)
- **Maintainers:** Engineering team (5 people)

This means we'll need to consider IT's security requirements and make it maintainable for a small team.

How will you measure success for this project? What are the key metrics or outcomes?

**User:** Main metric is adoption - we want 80% of the sales team checking the dashboard daily within the first month. Also want to reduce the time spent on manual reporting from 2-3 hours per week to zero.

**LLM:** Excellent concrete metrics:
- **Adoption:** 80% daily active users within 1 month
- **Time savings:** Eliminate 2-3 hours/week of manual work
- **Data freshness:** Real-time vs stale data

What's the minimum viable success? What must work for v1.0?

**User:** At minimum, it needs to show pipeline value by stage, deal count by rep, and forecast vs actual. If those three things work and update automatically, we're good.

**LLM:** Perfect - clear MVP scope. Now let's talk about constraints. What are the key constraints or requirements for this project?

**User:** Timeline is the big one - Sarah wants this live by end of Q2 (3 months from now). Budget is about $30K for development. We need to use our existing Salesforce instance and can't store customer data outside our approved cloud providers (AWS or GCP). No specific compliance requirements since it's internal only.

**LLM:** Got it. Key constraints:
- **Timeline:** Q2 launch (3 months) - hard deadline
- **Budget:** $30K development
- **Technical:** Must integrate with existing Salesforce, AWS/GCP only
- **Data:** No customer data storage restrictions (internal use)
- **Compliance:** None (internal tool)

Are any of these negotiable, or are they all hard constraints?

**User:** Timeline is hard - Sarah committed to the board. Budget has some flex if needed. The AWS/GCP requirement is hard (IT policy).

**LLM:** Understood. Now, what existing systems, services, or tools does this project need to work with?

**User:** Main integration is Salesforce - we need to pull data from their API. For auth, we use Google Workspace, so Google OAuth would be ideal. We're already on AWS for other services, so deploying there makes sense. We use Datadog for monitoring on our other apps.

**LLM:** Perfect. Ecosystem context:
- **Primary integration:** Salesforce API (data source)
- **Authentication:** Google Workspace (OAuth)
- **Infrastructure:** AWS (existing)
- **Monitoring:** Datadog (existing)

Do you have API access and credentials for Salesforce already?

**User:** Yes, IT has a service account set up for integrations.

**LLM:** Great - that removes a potential blocker. Now let's define scope. What's in scope for v1.0, and what's explicitly out of scope?

**User:** In scope: Pipeline by stage, deals by rep, forecast vs actual, auto-refresh every hour, Google OAuth login. Out of scope: Individual deal details, historical trends beyond 90 days, mobile app, custom reports, export to Excel.

**LLM:** Clear boundaries:
- **Must have:** Pipeline by stage, deals by rep, forecast vs actual, hourly refresh, Google OAuth
- **Won't have (v1.0):** Deal details, >90 days history, mobile app, custom reports, exports

This helps us stay focused. What about timeline and milestones?

**User:** We're starting now. I'd like Phase 0 done in a week, core functionality (Phase 1) in 6 weeks, then 6 weeks for testing and polish before the Q2 launch.

**LLM:** Timeline:
- **Now:** Project Context + Phase 0 (1 week)
- **Weeks 2-7:** Phase 1 development (core features)
- **Weeks 8-13:** Testing, polish, deployment
- **End of Q2:** Production launch (hard deadline)

That's aggressive but achievable. What's the plan after v1.0 launch?

**User:** Ongoing maintenance, and Sarah already has ideas for v2.0 features, but those can wait until after launch.

**LLM:** Perfect. Based on everything you've told me, here's my Quality level recommendation:

**Recommended Quality: Production**

**Reasoning:**
- Real users (50 people) depending on this for daily work
- Internal tool (no compliance requirements like HIPAA/GDPR)
- Needs reliability (sales team will rely on it)
- Should have monitoring (you already use Datadog)
- Needs security basics (Google OAuth, but not highly sensitive data)
- Timeline allows for production-quality work (3 months)

This means we'll complete:
- Project Context (done!)
- Phase 0: Project basics
- Phase 1: Core technical
- Phase 2: Infrastructure (AWS deployment)
- Phase 3: Authentication (Google OAuth)
- Phase 4: Security basics
- Phase 5: Operations (monitoring, logging)
- Phase 6: Data & Persistence (Salesforce integration, caching)
- Phase 7: User Interface (dashboard)

We'll skip the secure/compliance phases (11-16) since you don't have regulatory requirements.

Does this Quality level align with your expectations?

**User:** Yes, that makes sense. We need it to be reliable but don't need the full compliance overhead.

**LLM:** Perfect! Here's the complete project context:

**Problem:** Sales team spends 2-3 hours/week manually updating pipeline spreadsheets; leadership makes decisions on stale data  
**Users:** Sales team (50 people), VP Sales (sponsor), IT (approval), Engineering (maintainers)  
**Success:** 80% daily adoption within 1 month; eliminate manual reporting time  
**Constraints:** Q2 launch (hard), $30K budget (flex), AWS/GCP only (hard), Salesforce integration required  
**Ecosystem:** Salesforce API, Google OAuth, AWS, Datadog  
**Scope:** Pipeline/deals/forecast dashboard with hourly refresh; no mobile, no exports, no custom reports in v1.0  
**Timeline:** 1 week Phase 0, 6 weeks Phase 1, 6 weeks testing/polish, Q2 launch  
**Quality:** Production (Phases 0-7, skip compliance phases)

Does this accurately capture your project context?

**User:** Yes, perfect!

**LLM:** Excellent! I've created `docs/context/project_context.md` with all of this information.

Next steps:
1. Review the context document (make any corrections)
2. Proceed to Phase 0 Q&A (project basics: ~10 min)
3. Start Phase 0 implementation (v0.0.x - project setup)

Would you like to proceed to Phase 0 Q&A now, or take a break?

**User:** Let's keep going with Phase 0.

---

## Example Q&A Session 2: Personal Expense Tracker (Experiment Quality)

**LLM:** Before we dive into technical details, I'd like to understand the project context. This will take about 10-20 minutes. Ready?

**User:** Sure.

**LLM:** In 1-3 sentences, what problem does this project solve and for whom?

**User:** I want to track my personal expenses automatically. I'm tired of manually categorizing transactions in spreadsheets. Just for me, not planning to share it.

**LLM:** Got it - personal tool to automate expense tracking and categorization. What happens today without this solution?

**User:** I either don't track expenses at all, or I spend an hour at the end of the month manually entering everything into a spreadsheet.

**LLM:** Clear pain point. Who are the key stakeholders? Sounds like just you?

**User:** Yeah, just me. I'm the developer and the only user.

**LLM:** Perfect - that simplifies things significantly. How will you measure success?

**User:** If I actually use it consistently for 3 months, I'll consider it a success. Also want to see where my money is going each month.

**LLM:** Simple success criteria:
- **Usage:** Consistent use for 3 months
- **Outcome:** Visibility into spending patterns

What are the key constraints or requirements?

**User:** No budget since it's personal. No hard deadline - just want to build it when I have time. No compliance requirements. Would be nice to have it done in a few weeks but not critical.

**LLM:** Very flexible:
- **Timeline:** Flexible, few weeks target
- **Budget:** $0 (personal project)
- **Compliance:** None
- **Scale:** Just you

What existing systems does this need to integrate with?

**User:** I'd like to pull transactions from my bank automatically, but I'm not sure how that works yet. Maybe I'll just upload CSV files manually to start.

**LLM:** Ecosystem:
- **Phase 1:** Manual CSV upload (simple)
- **Future:** Bank API integration (explore later)

That's a smart approach - start simple. What's in scope for v1.0?

**User:** Upload CSV, categorize transactions (maybe with some rules), see monthly spending by category. That's it.

**LLM:** Clear MVP:
- **Must have:** CSV upload, categorization, monthly view
- **Won't have (v1.0):** Bank integration, budgeting, forecasting, mobile app

Timeline and milestones?

**User:** Start this weekend, hopefully have something working in 2-3 weeks. No hard deadline.

**LLM:** Based on everything you've told me, here's my Quality level recommendation:

**Recommended Quality: Experiment**

**Reasoning:**
- Solo project (just you)
- No external users
- No compliance requirements
- Flexible timeline
- Learning/exploration mindset
- May evolve or be abandoned

This means we'll complete:
- Project Context (done!)
- Phase 0: Project basics (minimal)
- Phase 1: Core technical (lightweight)

We'll skip all production/security phases since you don't need reliability guarantees or security hardening for a personal tool.

Sound good?

**User:** Perfect - I don't want to over-engineer this.

**LLM:** Exactly! Here's your project context:

**Problem:** Manual expense tracking is tedious; want automated categorization  
**Users:** Just you  
**Success:** Consistent use for 3 months; spending visibility  
**Constraints:** None (personal project, flexible timeline, no budget)  
**Ecosystem:** CSV upload (start), maybe bank API later  
**Scope:** CSV upload, categorization, monthly view; no bank integration or budgeting in v1.0  
**Timeline:** Start this weekend, 2-3 weeks target (flexible)  
**Quality:** Experiment (minimal phases, focus on core functionality)

Does this capture it?

**User:** Yep!

**LLM:** Great! I've created `docs/context/project_context.md`. 

Next: Phase 0 Q&A (5-10 min) to cover language/framework basics, then we'll start building.

Ready for Phase 0?

**User:** Let's do it.

---

## Tips for LLMs

### Do:
✅ Ask one question at a time  
✅ Provide concrete examples before each question  
✅ Listen for clues about Quality level (compliance, scale, timeline)  
✅ Summarize after each question to confirm understanding  
✅ Fill `docs/context/project_context.md` in real-time  
✅ Recommend Quality level based on constraints  
✅ Keep the session focused (10-20 minutes)  

### Don't:
❌ Ask about technical implementation details (that's Phase 0+)  
❌ Skip the Quality level recommendation  
❌ Let the session drag on (move forward if stuck)  
❌ Forget to create the context document  
❌ Make assumptions - ask clarifying questions  

### Quality Level Decision Tree

Use this to recommend the appropriate Quality level:

```
Does the project require compliance (HIPAA, GDPR, SOC 2, PCI DSS)?
├─ YES → Secure Quality
└─ NO → Continue

Will the project have production users and require uptime/reliability?
├─ YES → Production Quality
└─ NO → Continue

Is this validating an approach or building for a small team?
├─ YES → Prototype Quality
└─ NO → Continue

Is this a solo project, short-lived, or rapid experimentation?
├─ YES → Experiment Quality
└─ NO → Ask more questions to clarify
```

### Common Patterns

**Enterprise project indicators:**
- Multiple stakeholders with approval processes
- Compliance requirements (HIPAA, SOC 2, etc.)
- Hard deadlines tied to business commitments
- Integration with existing enterprise systems
- → Likely Production or Secure Quality

**Startup/small team indicators:**
- Small team (2-10 people)
- MVP mindset, validating approach
- Flexible timeline but want to move fast
- External users but limited scale
- → Likely Prototype or Production Quality

**Personal/solo project indicators:**
- Just the developer as user
- No external users or stakeholders
- Flexible timeline, no budget
- Learning or experimentation goal
- → Likely Experiment Quality

---

## Integration with Phase 0

After completing the Project Context Q&A, transition smoothly to Phase 0:

```
Great! Now that we understand the project context, let's cover the technical basics.
This is Phase 0 Q&A and will take about 10-15 minutes.

Based on your [Quality level], I'll ask [X] questions about:
- Language and framework selection
- Project structure and components
- Development environment setup

Ready to continue?
```

The Project Context informs Phase 0 decisions:
- **Quality level** → Determines question depth in Phase 0
- **Ecosystem** → Suggests language/framework choices
- **Constraints** → Limits technology options
- **Timeline** → Affects tooling choices (proven vs experimental)

---

## Updating the Project Context

The Project Context is a **living document** that can be updated as the project evolves.

**When to update:**
- Stakeholders change
- Scope changes significantly
- Constraints change (timeline, budget, compliance)
- Quality level upgrade (experiment → prototype → production → secure)
- Major pivot or direction change

**How to update:**
1. Re-run relevant questions from this Q&A
2. Update `docs/context/project_context.md`
3. Add entry to changelog section in the document
4. Consider if Quality level should change
5. If Quality level changes, conduct additional Q&A phases

**Changelog format:**
```markdown
## Changelog

### 2025-01-15: Scope Expansion
- Added mobile app to v2.0 roadmap (out of scope for v1.0)
- Increased budget to $50K to support additional features

### 2025-01-10: Compliance Requirement Added
- HIPAA compliance now required (customer request)
- Quality level upgraded: Production → Secure
- Timeline extended by 2 months for security implementation
```
