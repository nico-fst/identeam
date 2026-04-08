# AGENTS.md

## Core Principle
All code changes must be verified by tests.

## Workflow
- After every code change, run the relevant tests.
- If no tests exist, create appropriate tests before considering the change complete.
- Update existing tests if behavior changes.

## Verification
- Never claim a change works without running tests.
- If tests cannot be executed, explicitly state why.
- A task is only complete when tests pass.

## Output Requirements
In the final response, always include:
1. What was changed
2. Which tests were run
3. The result of those tests
4. Any remaining risks or uncertainties