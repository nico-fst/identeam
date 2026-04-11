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

## Codebase Notes
- The repo has two main parts: the Go backend in `backend/` and the iOS app in `identeam/`.
- Backend entrypoint is `backend/main.go`; HTTP routes and handlers live in `backend/api/`.
- Database access is organized in `backend/internal/db/`; shared request/response and DB models live in `backend/models/`.
- Auth middleware lives in `backend/middleware/`; helper utilities live in `backend/util/`.
- The backend can run with SQLite for local/dev flows (`USE_INTERNAL_DB=true`) or Postgres otherwise.
- Backend tests should live under `backend/test/`.
- Integration-style backend tests currently live in `backend/test/integration/feature_flow_test.go` and use a temporary SQLite DB via `app.setupRoutes(false)`.
- For backend work, prefer running tests from `backend/` with `go test ./...` or a targeted package test.

## Output Requirements
In the final response, always include:
1. What was changed (if you changed something)
2. Which tests were run (if you ran tests)
3. The result of those tests (if you ran tests)
Discuss remaining risks or uncertainties if there are any.
