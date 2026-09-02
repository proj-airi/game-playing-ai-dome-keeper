---
status: accepted
date: 2026-08-30
decision-makers: LemonNeko
---

# Adopt a Multi-Timescale Gameplay Agent

## Context and Problem Statement

The integration combines long-term planning with real-time keyboard and mouse
control. The selected large language model (LLM) cannot provide both time
scales.

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
  event. A state change does not restart an active inference.
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
  participant K as Keeper runtime
  participant G as Game
  participant V as Vision runtime
  participant U as Keeper Upper LLM
  participant L as Lower visual actor
  participant I as Input injector

  AIRI->>K: Start whole-run task with intent and context
  K->>G: Launch game
  K->>V: Start capture, recording, YOLO, and tracking
  K->>L: Load actor with no active task
  K->>I: Start injector and release all input
  G-->>V: Continuous rendered frames
  V-->>K: Ready at observed frame
  K->>U: Start Upper with whole-run context

  par Lower control loop
    loop Whenever a Lower task is active
      V-->>L: Recent frame history
      L->>I: Action(task instance, decision frame)
      I->>G: Keyboard and mouse input
    end
  and Upper reasoning loop
    loop While the whole-run task is active
      U->>V: Query current world state
      V-->>U: Structured snapshot(observed frame)
      U->>L: Query current Lower task state
      L-->>U: Active task and execution state
      opt A Lower task is active
        U->>V: Query task status(task instance)
        V-->>U: Status, evidence, task instance, observed frame
      end
      U->>U: Reconcile state, history, and whole-run goal
      alt Keep current task
        U-->>L: Keep current task
      else Start or replace task
        U->>L: Start(new task instance, bounded task)
        L->>I: Reject old output, release input, clear pending actions
        Note over L,I: Already-applied input remains in game state
        L-->>U: Replacement accepted
      end
    end
  and AIRI supervision
    loop On demand
      AIRI->>K: Query status or update whole-run context
      K->>U: Forward provided context updates
      K-->>AIRI: World summary, current task, history, progress
    end
  end

  alt AIRI stop, terminal game state, or fatal failure
    K->>U: Stop Upper loop and reject new output
    K->>L: Stop Lower actor
    L->>I: Release all input and clear pending actions
    K->>V: Stop capture and finalize recording
    K->>I: Stop injector
    K->>G: Close game
    K-->>AIRI: Report final status
  end
```

The participants are logical roles. They do not require separate processes.

## Consequences

- Lower control continues during Upper inference.
- Fresh world state helps the Upper Agent correct long-term drift.
- Upper reaction time is no shorter than one Upper iteration.
- Applied input cannot be reversed after task replacement.
- Vision results can be missing, stale, or uncertain. The interfaces preserve
  `unknown`, observed-frame identifiers, and task-instance identifiers.

## Rejected Options

| Option | Reason for rejection |
| --- | --- |
| One model for both time scales | LLM latency blocks real-time control. |
| Synchronous Upper and Lower execution | Upper reasoning stops during Lower control. |
| Completion-event Upper loop | Event lifecycle rules make the Upper Agent a dispatcher. |
| Queued Lower tasks | The queue can run decisions from stale state. |

## References

- [Vision, Datasets, and Inference](../vision.md)
- [Hi Robot](https://www.pi.website/research/hirobot)
- [RT-H: Action Hierarchies Using Language](https://rt-hierarchy.github.io/)
- [SayCan](https://say-can.github.io/)

If Lower tasks cannot isolate real-time control from Upper inference, revisit
this decision. If AIRI cannot host continuous tool calling, revisit this
decision.
