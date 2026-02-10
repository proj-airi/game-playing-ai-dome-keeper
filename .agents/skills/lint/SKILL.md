---
name: lint
description: Run ESLint --fix and TypeScript typecheck after code edits in this repo. Use when Codex has modified files and should lint and typecheck before responding.
---

# Lint

## Overview

Run ESLint auto-fix and TypeScript typecheck after file changes so the repo stays consistent and clean. Only run when this conversation has changed files in the workspace.

## Workflow

1. Check whether files were modified in this repo during the current response.
2. If no files changed, skip linting.
3. If files changed:
4. Run ESLint with auto-fix via Bun:
   - Preferred: `bun run lint -- --fix`
   - Fallback: `bunx eslint --fix .`
5. Run typecheck:
   - Preferred: `bun run typecheck`
   - Fallback: `bunx tsc -p tsconfig.json`
6. Report the lint/typecheck results succinctly in the response.

## Notes

- If `bun run lint -- --fix` fails because the script doesn't exist, use `bunx eslint --fix .`.
- If `bun run typecheck` fails because the script doesn't exist, use `bunx tsc -p tsconfig.json`.
- If ESLint or typecheck report errors, report them and stop; do not silently ignore.
