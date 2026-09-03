---
status: accepted
date: 2026-08-30
amended: 2026-09-03
decision-makers: LemonNeko
---

# Adopt a Multi-Timescale Gameplay Agent

## Context and Problem Statement

The integration combines long-term planning with real-time keyboard and mouse
control. The selected large language model (LLM) cannot provide both time
scales.

The game is the ongoing environment input. The gameplay task does not wait for
user input after AIRI starts it. The project has no evidence that it needs
event-driven inference cancellation.

The project needs stable boundaries between AIRI, the Upper Agent, and the
Lower Agent.

## Decision

Use a three-level hierarchy: AIRI, an Upper Agent, and a Lower Agent.

The runtime obeys these rules:

- AIRI owns user intent, memory, and the whole-run task. Keeper handles runtime
  lifecycle and status.
- Vision supplies recent frames and YOLO-derived world state. It also returns
  task status and frame-derived evidence.
- The Upper Agent uses structured state, not screenshots, in its normal path.
  Only the Upper Agent can replace a Lower task.
- The Upper Agent runs a continuous tool loop without a timer or completion
  event. When the current iteration ends, the runtime starts the next iteration.
  Each iteration queries the latest available state.
- A state update during play does not restart active Upper inference. The next
  iteration observes the latest state.
- The Lower Agent executes one bounded task during Upper inference. One game
  has no more than one active Lower task.
- `start` replaces the active task without a queue or separate cancel operation.
  Replacement rejects old output, releases input, and clears pending actions.
- World state results include an observed-frame identifier. Actions and task
  results include a task-instance identifier. Consumers reject stale data.
- Applied input stays in the game. The next state query lets the Upper Agent
  correct its plan.
- Deployed Lower control uses operating-system input. In-game input is only for
  controlled tests or approved data generation.

### Runtime Sequence

Startup and shutdown occur once for each whole-run task. During play, the Upper
loop, Lower loop, and AIRI supervision operate concurrently. One frame stream
supplies all vision roles and configured recording.

```mermaid
sequenceDiagram
  autonumber
  actor AIRI
  participant U as Keeper Upper LLM
  participant L as Lower visual actor

  AIRI->>U: Start whole-run task with intent and context
  U->>L: Initialize with no active task
  Note over U,L: State updates do not interrupt active Upper inference

  par Lower control loop
    loop Whenever a Lower task is active
      L->>L: Observe recent frame history
      L->>L: Apply action(task instance, decision frame)
    end
  and Upper reasoning loop
    loop While the whole-run task is active
      U->>U: Observe structured world state
      U->>L: Query current Lower task state
      L-->>U: Active task and execution state
      opt A Lower task is active
        U->>U: Observe task status and frame-derived evidence
      end
      U->>U: Reconcile state, history, and whole-run goal
      alt Keep current task
        U-->>L: Keep current task
      else Start or replace task
        U->>L: Start(new task instance, bounded task)
        L->>L: Reject old output, release input, clear pending actions
        Note over L: Already-applied input remains in world state
        L-->>U: Replacement accepted
      end
    end
  and AIRI supervision
    loop On demand
      AIRI->>U: Query status or update whole-run context
      U-->>AIRI: World summary, current task, history, progress
    end
  end

  alt AIRI stop, terminal game state, or fatal failure
    U->>U: Stop Upper loop and reject new output
    U->>L: Stop actor, release input, clear pending actions
    U-->>AIRI: Report final status
  end
```

The participants are logical roles. They do not require separate processes.

## Consequences

- Lower control continues during Upper inference.
- Fresh world state helps the Upper Agent correct long-term drift.
- A state update can occur after an iteration reads state. The Upper Agent then
  reacts after the current iteration and its next inference.
- The Upper Agent consumes inference capacity for the whole-run task. This use
  continues while the Lower task remains active.
- The latency benchmark determines whether the runtime needs event-driven
  inference cancellation.
- Applied input cannot be reversed after task replacement.
- Vision results can be missing, stale, or uncertain. The interfaces preserve
  `unknown`, observed-frame identifiers, and task-instance identifiers.

## Rejected Options

| Option | Reason for rejection |
| --- | --- |
| One model for both time scales | LLM latency blocks real-time control. |
| Synchronous Upper and Lower execution | Upper reasoning stops during Lower control. |
| Completion-event Upper loop | The Upper Agent cannot reason proactively while the Lower task runs. |
| Mandatory event-driven inference cancellation | It adds cancellation machinery before latency measurements show that continuous inference is too slow. |
| Queued Lower tasks | The queue can run decisions from stale state. |

## References

- [Vision, Datasets, and Inference](../vision.md)
- [Hi Robot](https://www.pi.website/research/hirobot)
- [RT-H: Action Hierarchies Using Language](https://rt-hierarchy.github.io/)
- [SayCan](https://say-can.github.io/)

If measured Upper latency misses gameplay requirements, revisit event-driven
inference cancellation. If Lower tasks cannot isolate real-time control from
Upper inference, revisit this decision. If AIRI cannot host continuous tool
calling, revisit this decision.
