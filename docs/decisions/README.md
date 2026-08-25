# Architecture Decision Records

Architecture Decision Records (ADRs) preserve the reasons for consequential
architecture decisions for future maintainers and coding agents. They are the
only project documents that retain superseded design history. All other active
documentation describes only the system as it currently exists.

## Conventions

- Store ADRs in this directory as `NNNN-present-tense-verb-phrase.md`.
- Write ADRs in English with repository-relative links.
- Create a new ADR as `proposed`; a human decision-maker changes it to
  `accepted` or `rejected`.
- Preserve accepted ADRs. When a later decision replaces one, create a new ADR
  and mark the old ADR as `superseded` with links in both directions.
- Use an ADR only for a consequential decision with real alternatives whose
  rationale will matter to future implementation. Routine changes, debugging
  notes, and changelogs do not belong here.
- Keep each ADR self-contained, with explicit non-goals, an implementation
  plan, and verifiable completion criteria.
- Do not execute helper scripts bundled with `adr-skill` in this repository.
  Use its instructions and templates through ordinary repository file editing;
  the bundled CommonJS scripts are incompatible with the repository's ESM
  Node.js boundary.

## Workflow

1. Consult accepted ADRs before making an architectural change.
2. Capture the decision intent and alternatives before drafting a new ADR.
3. Add the proposed ADR to this index and obtain human approval.
4. Implement accepted decisions and verify their stated criteria.
5. Supersede rather than rewrite or delete historical decisions.

## ADRs

- [ADR-0001: Adopt Architecture Decision Records](0001-adopt-architecture-decision-records.md) (accepted, 2026-08-25)
- [ADR-0002: Model Target Activation as Compound Tasks](0002-model-target-activation-as-compound-tasks.md) (accepted, 2026-08-25)
