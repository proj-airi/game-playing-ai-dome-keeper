# TODO

This document owns confirmed maintenance, cleanup, and behavior-correction work. An item authorizes only its stated scope and does not settle unstated architecture or design choices.

## Teacher Controller Cleanup

- After a fresh gameplay recording and teacher log confirm the current shaft-shift and descent-backtracking behavior, schedule a dedicated teacher cleanup before the planned Relic Hunt expansion without turning it into a blanket gate on urgent fixes. Establish explicit expected observable outcomes for the representative lifecycle scenarios in scope rather than preserving one recording's exact action trace. Audit the current code and state-machine logic for dead or duplicated paths, unreachable transitions, unclear state ownership, accidental coupling, and contradictory invariants; identify responsibility boundaries without presuming that every large function or file must be split. Keep each batch independently reviewable and verifiable. Pure refactors must preserve the declared outcomes, while defect or policy corrections must declare the corrected expectation and receive targeted runtime validation.

## Gadget Choice Water Reroll

- Consider bounded normal-UI use of a paid water reroll during the currently
  supported Gadget choice flow. Before implementation, decide when rerolling is
  preferable to the current supported offer or shred fallback, how pending
  upgrade resource reservations constrain water spending, when rerolling must
  stop, and how the available free-reroll pool participates. After each
  confirmed reroll, re-evaluate the regenerated offers and authoritative reroll
  availability and cost before acting again. Keep Supplement rerolls outside
  this task until their acquisition flow enters the supported scope.

## Laser Targeting Behavior Correction

- Defer changes intended to reduce wide Laser rotations and repeated target switching to a dedicated behavior-fix batch; they are not part of teacher cleanup or a behavior-preserving refactor. Static inspection shows that the current teacher reselects from the active wave on every physics tick, prioritizes current damageability and then dome distance, and does not retain target identity, while the Stun Laser retains its own target and uses a different stun-priority, range, angular-ranking, steering, and fire policy that is not a directly reusable normal-Laser selector. Before implementation, declare the expected observable outcomes for representative same-tier crossings, runtime damageability changes, target death or departure, visibility loss, opposite-side candidates, persistent ray blockers, and `WORM_ROCK` or projectile intersections; capture target identity, switch reason, signed angular error, and the normal Laser's ordered first collider during validation. Preserve the existing intentional-target and exact-acquisition fire gates unless a separate product decision changes them. Do not prescribe target retention, minimum-turn ranking, hysteresis, fairness, or acquisition-timeout rules until runtime evidence distinguishes ordinary necessary traversal from pathological target oscillation.
