---
description: Implement one or more work items (tracker refs, or a description of the work)
argument-hint: <issue refs | description of the work>
---

Implement the following work item(s): $ARGUMENTS

- Follow the **harness:development** skill. Its "Tracker mode" section says how to tell whether a tracker is active.
- The arguments are tracker refs (e.g. `42 43`) when a tracker is active and they look like refs; otherwise they are a free-text description of the work, or a path to a plan file to read.
- Assess dependencies and the proper order to implement.
- Work through items sequentially. For each item, read it first, then implement, then handle git and (with a tracker) status and logging.
