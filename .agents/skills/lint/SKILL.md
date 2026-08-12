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
4. Run ESLint with auto-fix via pnpm:
   - Preferred: `pnpm run lint --fix`
   - Fallback: `pnpm exec eslint --fix .`
5. Run typecheck:
   - Preferred: `pnpm run typecheck`
   - Fallback: `pnpm exec tsc -p tsconfig.json`
6. Report the lint/typecheck results succinctly in the response.

## Notes

- If `pnpm run lint --fix` fails because the script doesn't exist, use `pnpm exec eslint --fix .`.
- If `pnpm run typecheck` fails because the script doesn't exist, use `pnpm exec tsc -p tsconfig.json`.
- If ESLint or typecheck report errors, report them and stop; do not silently ignore.
