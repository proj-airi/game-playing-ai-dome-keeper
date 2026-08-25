---
status: accepted
date: 2026-08-25
decision-makers: LemonNeko
---

# Adopt Architecture Decision Records

## Context and Problem Statement

The repository's active documentation is a current contract for users,
maintainers, and coding agents. It deliberately removes superseded behavior and
design history so readers can understand how the project works now without
sorting through obsolete alternatives.

Coding agents nevertheless tend to preserve the reasoning and evolution behind
designs. When that history is added to active documentation, it violates the
current-documentation contract and burdens end users with information they do
not need. Deleting every explanation avoids that noise, but also discards the
rationale future maintainers and agents need when revisiting consequential
architecture choices.

The project needs one explicit location for durable architecture decision
history without allowing that history to spread back into active documentation.

## Decision

Adopt Architecture Decision Records (ADRs) under `docs/decisions/`.

ADRs are the only project documents allowed to retain superseded architecture
decision history. All other active documentation continues to describe only
the current system and must remove superseded designs. An ADR is appropriate
only when a decision has real alternatives and is consequential, difficult to
reverse, establishes a pattern other work must follow, or has rationale that a
future maintainer or coding agent will need.

Use these conventions:

- Name ADRs `NNNN-present-tense-verb-phrase.md` and list every ADR in
  `docs/decisions/README.md`.
- Write ADRs in English and use repository-relative links.
- Start undecided records as `proposed`. A human decision-maker changes the
  status to `accepted` or `rejected`.
- Preserve accepted ADRs. Replace a decision by creating a new ADR and marking
  the old one `superseded`, with links in both directions.
- Make each ADR self-contained and include explicit scope, non-goals,
  consequences, affected paths, implementation guidance, and verifiable
  completion criteria.
- Consult relevant accepted ADRs before implementing architectural changes.

ADRs do not record routine implementation work, debugging history, changelogs,
or every code modification. They do not replace current documentation, Git
history, issues, or tests.

## Consequences

- Good, because active documentation remains concise and useful to end users
  who need the current behavior rather than its design evolution.
- Good, because future maintainers and coding agents have a discoverable,
  version-controlled explanation for consequential architecture choices.
- Good, because superseded reasoning has one bounded home instead of leaking
  into every subsystem document.
- Bad, because qualifying decisions require an additional drafting, approval,
  indexing, and review step.
- Bad, because maintainers must distinguish durable architecture decisions from
  routine implementation details; the scope rules above mitigate uncontrolled
  ADR growth.
- Neutral, because an obsolete ADR remains in the repository, but its status
  and superseding link make clear that it no longer governs current work.

## Implementation Plan

- **Affected paths**:
  - `docs/decisions/README.md` owns ADR conventions, workflow, and the index.
  - `docs/decisions/NNNN-*.md` contains decision records.
  - `AGENTS.md` routes agents to the ADR index and defines ADRs as the sole
    exception to the current-documentation history rule.
  - `apm.yml` and `apm.lock.yaml` pin the repository's `adr-skill` workflow.
  - `.gitignore` excludes installed APM package contents rather than committing
    generated skill files.
- **Dependencies**: use the `skillrecordings/adr-skill` commit pinned in
  `apm.yml` and `apm.lock.yaml`; this adds no application runtime dependency.
- **Patterns to follow**: use the status lifecycle and numbered filenames in
  `docs/decisions/README.md`; keep active subsystem documents current when an
  ADR changes their behavior.
- **Patterns to avoid**: do not preserve design history outside
  `docs/decisions/`; do not rewrite or delete accepted ADR history; do not
  create ADRs for routine changes merely to archive implementation work.
- **Configuration**: contributors install the repository-managed ADR skill with
  `apm install`; no application configuration or data migration is required.

### Verification

- [x] `docs/decisions/README.md` defines the conventions and links ADR-0001.
- [x] `AGENTS.md` links the ADR index and identifies ADRs as the only exception
  to deletion of superseded design history from active documentation.
- [x] `apm.yml` and `apm.lock.yaml` pin `skillrecordings/adr-skill`, while
  `.gitignore` excludes its installed contents.
- [x] Every repository-relative link added by this decision resolves to an
  existing file.
- [x] Focused Markdown and whitespace checks pass for the changed documents.

## Alternatives Considered

- Rely only on Git history: commits preserve chronological changes but do not
  provide a discoverable, self-contained explanation of a decision, its
  alternatives, consequences, and current status.
- Preserve design history in ordinary documentation: the history would be easy
  to find, but end users do not need it, it increases their comprehension cost,
  and it violates the repository rule that active documentation describes only
  the current system.

## More Information

- [Architecture Decision Record index](README.md)
- [Repository documentation workflow](../../AGENTS.md#documentation-workflow)

Revisit this decision if ADR volume makes the flat index difficult to navigate;
at that point, introduce documented categories without moving unrelated active
documentation into the ADR hierarchy.

### 2026-08-25: Do Not Execute Bundled ADR Scripts

Running the bundled `bootstrap_adr.js` through the mise-managed Node.js runtime
failed because the script uses CommonJS `require()` while the repository root
declares `"type": "module"`. The project therefore consumes `adr-skill` as
instructions and templates only; ADR files and indexes are created and updated
with ordinary repository editing tools. This preserves the repository's
[Node.js ESM boundary](../references.md#development-toolchain) without patching,
forking, or wrapping the upstream skill scripts.
