# ViDot as a Code-as-Policy Game Driver

**Status: non-binding personal dream outside project scope, architecture, and
roadmap.** There is no commitment or authorization to implement it, and it
must not influence present ViDot or DataCollectorAI work.

One possible future direction is to reuse ViDot's Godot automation boundary as
an execution interface for LLM-generated gameplay policies. This resembles the
way Playwright's browser automation API can serve deterministic tests, scripts,
and agent workflows without making its test runner responsible for the agent.

The first version of such an experiment would keep policy execution in Node.js.
An LLM could generate TypeScript that observes game state and composes existing
ViDot calls to invoke project methods, simulate inputs, and wait for observable
conditions. ViDot would remain unaware of the policy author and would not need
dynamic GDScript execution. Successful policies could be retained as readable,
reviewable programs, following the broad code-as-policy idea explored by
Voyager and related embodied-control research.

Executing generated code inside the Godot process is a separate, optional
possibility. Revisit it only if evidence shows that Node-side policies cannot
meet a concrete latency, lifecycle, or engine-access requirement. At that time,
define trust, cancellation, timeout, cleanup, error reporting, and state
isolation boundaries from scratch rather than reserving a `run_script` command
in the present protocol.

This dream creates no requirement for an LLM integration, MCP server, policy
library, arbitrary code execution, additional ViDot command, or future-proofing
of the test framework.

Possible background reading, relevant only to this dream:

- [Playwright](https://playwright.dev/)
- [Voyager: An Open-Ended Embodied Agent with Large Language Models](https://arxiv.org/abs/2305.16291)
- [Code as Policies: Language Model Programs for Embodied Control](https://arxiv.org/abs/2209.07753)
