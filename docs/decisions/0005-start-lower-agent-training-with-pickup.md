---
status: proposed
date: 2026-09-05
updated: 2026-09-06
decision-makers: LemonNeko
---

# Start Lower-Agent Training with Pickup

## Context

[ADR-0004](0004-adopt-a-multi-timescale-gameplay-agent.md) defines the Upper and
Lower roles. The project needs a first learned Lower task and automatic
demonstrations to evaluate visual control.

`PickupTargetTask` already approaches an exact `Carryable`, obtains focus, and
applies pickup input. It completes when the Keeper carries that object.
The existing integration test covers one iron Drop in an open area.
It does not provide a varied training dataset or evidence of model performance.

`Move` is a Quark Action shared by tasks such as Pickup. The existing
`MoveToTask` instead specifies an arbitrary map coordinate.
A coordinate can lack a visible landmark, so its model-facing representation
requires a separate decision. Pickup supplies a concrete object and outcome
while still requiring movement.

The available hardware is an Apple M5 Pro with 64 GB unified memory and an
RTX 3060 with 12 GB VRAM. The project excludes the VPT training route under
this resource constraint. Its behavior-cloning ideas remain useful.
Human gameplay demonstrations are not required. TaskExecutor supplies the
demonstrations.

## Decision

The first Lower training experiment uses offline behavior cloning for the
Pickup primitive task. TaskExecutor generates demonstrations through the
existing `PickupTargetTask`. One end-to-end classifier predicts the next
configured action from recent game frames and past applied actions.
Behavior cloning is supervised learning from observations and demonstrated actions.
Offline training reads recorded episodes without a running game or teacher.

The initial scenario contains one visible iron Drop in an open, reachable
area. The Keeper starts without cargo. Scenario variations change the Keeper
position, target position, direction, and distance within this scope.
The task is always to pick up the sole target, so this experiment does not
require a language instruction or selection among several objects.

The teacher and the learned model have distinct evidence boundaries:

- The teacher can use game state to select actions and label outcomes.
- The model observes game frames and past applied actions. Teacher coordinates,
  object references, focus state, and carry state are not model inputs.
- The teacher labels success when the exact target enters the Keeper's carried
  set. This label describes the demonstration outcome, not a model prediction.
- Scenario setup can prepare game state before execution. Execution uses
  configured input without direct game-state mutation.
- Teacher demonstrations identify their in-game input source. Deployed Lower
  control uses operating-system input, as required by ADR-0004.

This decision fixes the first experiment's data semantics, model family, and
training objective. The [roadmap](../roadmap.md#start-lower-agent-training-with-pickup)
owns implementation and verification. Live model control and game-execution
evaluation are separate, deferred work.

### Initial Control Cadence

TaskExecutor checks task completion and failure and updates input once every
six physics frames. This cadence is 10 Hz at the game's default 60 Hz physics
rate. Game physics and rendering retain their existing rates.
Task startup and compound child transitions remain immediate.
Held input persists between checks. Cancellation and scene removal submit
release events immediately and reset the frame counter.
Godot delivers those events through its normal input processing.

Capture preserves this timing, including immediate lifecycle transitions.
A lower video frame rate alone does not establish a matching control cadence.

### Recorded Data

An episode is one Pickup attempt, from the initial observation through the
terminal outcome and input release. Episodes start with no held input.
The collector saves full episodes, not separate copies of overlapping windows.
The required data are:

| Record | Required content | Purpose |
| --- | --- | --- |
| Episode | Episode identifier, reproducible scenario configuration, game and teacher versions, input source, and configured key bindings | Reproduction and dataset splits |
| Observation | Frame identifier, capture time, physics-frame index, and full 384-pixel-wide by 216-pixel-high RGB image | Model input and alignment |
| Applied input | Initial held state and ordered press/release events, with submission and application timing | Reconstruction of past actions |
| Decision | Decision time and physics-frame index, associated observation identifier, and selected action class | Supervised target |
| Outcome | Success, failure, timeout, or interruption, with terminal time and reason | Episode selection and diagnostics only |

The frame contains the game view without teacher annotations or debug overlays.
The image retains the full 16:9 view, without a center crop.
Observations and decisions use the 10 Hz cadence. Every decision has a record,
including decisions that keep the same held action.
Frames and input events share an ordered episode timeline.
Godot can buffer submitted input, so submission time is not proof of application time.

The terminal record preserves the exact-target success check and input release.
Failed, timed-out, interrupted, or invalid captures remain available for diagnostics.
Only successful episodes with valid frame/action alignment supply the first
supervised training and validation samples.
Unsupported actions and missing observations are data errors, not substitute labels.

### Sliding Window and Causal Alignment

Each sample predicts action `A_t` at decision `t` from these inputs:

- Ten frames, `F_(t-9)` through `F_t`, in chronological order.
- Ten corresponding held-action states, `H_(t-9)` through `H_t`.

`F_t` is the latest completed frame available before decision `A_t`.
`H_i` is the applied input state at capture of `F_i`, before its associated decision.
It describes past control, not the new target action.
The input never includes `A_t`, a later frame, or the episode outcome.
The held-action states use six-component one-hot encoding with the action order defined next.

The window advances by one observation every 0.1 seconds of game time.
Ten observations span 0.9 seconds between the oldest and newest frames.
At episode start, missing frame slots repeat the first frame.
Missing action slots use the no-input class.
Windows never cross episode boundaries or missing observations.
Immediate lifecycle events retain their actual times instead of fabricated 10 Hz sample times.

Each whole episode belongs to one dataset split before window construction.
Repeated captures of the same scenario belong to the same split.
Training updates parameters. Validation measures held-out predictions and selects
checkpoints. A separate test split remains untouched during model selection.

### Action Classes

The output class order is fixed:

| Class index | Representation | Meaning |
| --- | --- | --- |
| 0 | `ui_up` | Hold the configured up key |
| 1 | `ui_down` | Hold the configured down key |
| 2 | `ui_left` | Hold the configured left key |
| 3 | `ui_right` | Hold the configured right key |
| 4 | `keeper1_pickup` | Hold the configured pickup key |
| 5 | `none` | Release input held by this controller |

The dataset represents no input as `none`. TaskExecutor currently represents
that state as an empty string. The class specifies the desired held state,
not an isolated keypress event or a text-generation target.
The same class on consecutive steps preserves the held key.
Only one action is active at a time, as in the current teacher.

A successful terminal decision supplies a `none` target with its preceding observation.
Forced releases from cancellation, failure, or timeout are not successful-action labels.
The `none` class does not mean that the model declares task completion.

### Model and Training Objective

One shared ResNet-18 convolutional neural network (CNN) processes every frame.
It starts from Torchvision's `ResNet18_Weights.IMAGENET1K_V1` weights.
Its original ImageNet classification layer does not form part of the action predictor.
Chronological frame features and encoded past actions feed a multilayer
perceptron (MLP), which outputs six class scores.
The new MLP starts with random weights. Training jointly updates the CNN and MLP.
This is one end-to-end model, not separately trained feature and action models.

Preprocessing scales RGB values to `[0, 1]`, then applies channel normalization
with mean `[0.485, 0.456, 0.406]` and standard deviation `[0.229, 0.224, 0.225]`.
The default 224-by-224 center crop is not used.
Training and validation use the same full-frame preprocessing.

The objective is mean cross-entropy between the six predicted scores and the
teacher's action-class index. No reward, completion classifier, or reinforcement
learning objective forms part of this experiment.
Outcome metadata selects valid demonstrations but does not enter the loss as a target.
The first report includes held-out loss, action accuracy, per-class results,
and class counts. A common-action baseline makes class imbalance visible.

ImageNet pretraining supplies an initial visual representation, not knowledge
of the game. Its benefit on these game frames requires measurement.
The fixed window gives explicit recent history without a recurrent neural network.

## Consequences

The existing task and fixture provide a starting point for automatic
demonstrations. No human recording session or complete compound-task library
is a prerequisite.

Video alone does not preserve action targets or input timing.
The collector must preserve decision records as well as actual input events.
The model learns from teacher histories, so errors during future live control
can produce situations absent from the demonstrations.

An offline checkpoint and its held-out report are the first deliverable.
Teacher success and action-prediction accuracy do not establish model gameplay success.
That claim requires later game execution on reserved scenarios.
The first experiment does not establish general navigation, target selection,
or the final Upper-to-Lower task boundary.

## Open Decisions and Non-Goals

The dataset container, capture entry point, and capture ownership remain open.
These implementation choices must preserve the data semantics in this ADR.
Dataset size, split proportions, MLP dimensions, feature reduction, optimizer,
learning rate, batch size, and numerical acceptance thresholds remain experiment configuration.
Memory use and training speed require measurements on the available hardware.

Model loading in ViDot, an inference RPC, and changes that make TaskExecutor
wait for model inference are not part of this decision.
Model deployment, its input adapter, and game-execution evaluation remain deferred.
The existing teacher tests remain independent of the offline trainer.
The first classifier does not learn to report task completion.

Language and visual goal representations remain open for later target
selection experiments. MineCLIP-style text and video alignment and a
conditional variational autoencoder (CVAE) remain research ideas.
This decision adopts neither their implementations nor their pretrained weights.

This decision does not remove `MoveToTask`, redefine the existing task hierarchy,
or change the accepted runtime architecture. It does not assign capture
ownership or re-enable the legacy collector.

## Alternatives

| Alternative | Tradeoff and reason for deferral |
| --- | --- |
| Start with arbitrary-coordinate MoveTo | Input control is simple, but the model needs an unambiguous destination representation first. |
| Start with laser attack | The target and outcome are concrete, but aiming, occlusion, and damage eligibility add distinct visual requirements. |
| Start with activation | The target is concrete, but domain outcomes differ. Pickup already has a direct carried-object completion condition. |
| Start with compound tasks | They exercise longer behavior, but add sequencing before the project measures learned primitive control. |
| Recurrent history processing | RNNs summarize history in a hidden state. The first experiment uses an explicit fixed window before it measures a need for longer memory. |
| Train the visual network from random weights | This removes reliance on photo pretraining but discards reusable visual initialization. It remains a later comparison, not the first training path. |
| Couple model inference to the teacher test runtime | This adds model lifecycle, communication, and input-routing decisions that offline training does not require. |

## References

- [Pickup implementation](../../mods/LemonNekoGH-DataCollectorAI/src/tasks/pickup_target_task.ts)
- [Pickup integration test](../../mods/LemonNekoGH-DataCollectorAI/test/pickup.test.ts)
- [DataCollectorAI runtime design](../../mods/LemonNekoGH-DataCollectorAI/README.md#runtime-design)
- [Lower-Agent prior-art research](../research/lower-agent-prior-art.md)
- [Behavior cloning](https://imitation.readthedocs.io/en/latest/algorithms/bc.html)
- [ResNet-18 weights and preprocessing](https://docs.pytorch.org/vision/stable/models/generated/torchvision.models.resnet18.html)
- [PyTorch transfer learning](https://docs.pytorch.org/tutorials/beginner/transfer_learning_tutorial.html)
- [Cross-entropy loss](https://docs.pytorch.org/docs/stable/generated/torch.nn.CrossEntropyLoss.html)
- [Godot physics tick rate](https://docs.godotengine.org/en/4.3/classes/class_engine.html#class-engine-property-physics-ticks-per-second)
