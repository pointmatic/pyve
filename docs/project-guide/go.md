# Project-Guide — Calm the chaos of LLM-assisted coding

This document provides step-by-step instructions for an LLM to assist a human developer in a project. 

## How to Use Project-Guide

### For Developers
After installing project-guide (`pip install project-guide`) and running `project-guide init`, instruct your LLM as follows in the chat interface: 

```
Read `docs/project-guide/go.md`
```

After reading, the LLM will respond:
1. (optional) "I need more information..." followed by a list of questions or details needed. 
  - LLM will continue asking until all needed information is clear.
2. "The next step is ___."
3. "Say 'go' when you're ready." 

For efficiency, when you change modes, start a new LLM conversation. 

### For LLMs

**Modes**
This Project-Guide offers a human-in-the-loop workflow for you to follow that can be dynamically reconfigured based on the project `mode`. Each `mode` defines a focused sequence of steps to guide you (the LLM) to help generate artifacts for some facet in the project lifecycle. This document is customized for plan_concept.

**Approval Gate**
When you have completed the steps, pause for the developer to review, correct, redirect, or ask questions about your work.  

**Rules**
- Work through each step methodically, presenting your work for approval before continuing a cycle. 
- When the developer says "go" (or equivalent like "continue", "next", "proceed"), continue with the next action. 
- If the next action is unclear, tell the developer you don't have a clear direction on what to do next, then suggest something. 
- Never auto-advance past an approval gate—always wait for explicit confirmation. 
- After compacting memory, re-read this guide to refresh your context.

---

# plan_concept mode (sequence)

> Generate a high-level concept (problem and solution space)


Define the problem space (problem statement, why, pain points, target users, value criteria) and the solution space (solution statement, goals, scope, constraints), and pain point to solution mapping.

**Next Action**
Prompt the user to change modes. 

```bash
project-guide mode plan_features
```

---


## Prerequisites

Before starting, the developer must provide (or the LLM must ask for):

1. **A project idea** -- a short description of what the project should do (a few sentences to a few paragraphs). This is often documented in a `docs/specs/idea.md` file.

## Steps

1. Define the problem space 
   - problem_statement: A few sentences describing the problem, plus any other useful context, examples, or references
   - problem_why: Root causes of the problem and why the problem persists
   - pain_points: A list of points 
   - target_users: A description of those impacted by the problem (positively/negatively, directly/indirectly)
   - value_criteria: How to measure solution value
2. Define the solution space 
   - one_liner: A catchy, benefit-oriented phrase starting with a verb that completes the sentence "This project <one_liner>."
   - solution_statement: A few sentences that describe the solution in action, benefitting the target users, with some hints at technical approach
   - goals: How the solution addresses the value criteria
   - scope: What the solution will and won't do
   - constraints: Technical, regulatory, or business limitations
3. Map pain points to solution
   - pain_point_to_solution_mapping: A mapping of pain point labels to descriptions on how the solution addresses the pain in the pain_point_to_solution_mapping format below. 
   
## Formats

### pain_points

```markdown
- **<pain_point_label_1>**: <pain_point_description_1>
- **<pain_point_label_2>**: <pain_point_description_2>
- ...
```

### pain_point_to_solution_mapping

```markdown
**<pain_point_label_1>**: 
  - <solution_description_1>
  - <solution_description_2>
  ...
**<pain_point_label_2>**: 
  - <solution_description_1>
  - <solution_description_2>
  ...
...
```

