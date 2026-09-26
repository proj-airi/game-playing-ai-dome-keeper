---
name: lint
description: Run the repository's pinned ESLint auto-fix and TypeScript checks after code edits.
---

# Lint

After changing JavaScript, TypeScript, Vue, or their tool configuration in this
repository, run `mise exec -- pnpm run lint --fix`, then `mise run typecheck`.

Report each result. If typechecking needs a machine-local decompiled Dome Keeper
project or generated game typings that are absent, report that missing input;
do not create substitute typings or suppress the errors.
