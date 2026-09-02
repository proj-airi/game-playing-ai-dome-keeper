# Lower-Agent Prior Art

This note summarizes ideas that can inform Lower-Agent experiments. It does
not reproduce the papers or define project requirements.

The runtime role decision is
[ADR-0004](../decisions/0004-adopt-a-multi-timescale-gameplay-agent.md).

## 2026-08-30: Project Nabla and Phillip

### Approach

- Project Nabla starts with behavior cloning from Slippi tournament replays.
  It then adds a small self-play reinforcement-learning stage.
- Slippi replays contain controller input and structured game state. They do
  not require action inference or visual perception.
- Phillip learns through reinforcement learning from privileged game state.
- The delayed Phillip variant uses action queues, recurrent memory, and
  execution-time state prediction.
- Slippi-AI combines behavior cloning with later self-play training.

### Public Limits

- Nabla has an announcement, but its technical article is unavailable.
- Nabla does not publish enough detail for reproduction. Missing details include
  observations, actions, models, losses, rewards, and opponent sampling.
- Phillip and Slippi-AI publish code, but their structured input removes the
  visual-perception problem that Dome Keeper must solve.

### Useful Ideas for This Project

- Phillip can inform reward timing, parallel sampling, action queues, and
  execution-time state prediction.
- Self-play does not apply to current single-player gameplay. It becomes useful
  only after multiplayer support supplies an opponent.
- A deployed actor cannot use privileged game state. A teacher can use that
  state for labels and evaluation.
- Code-generated demonstrations are teacher distillation, not human behavior
  cloning. They preserve the limits of the teacher.
- A visual actor needs frame history for motion, action phase, and hidden state.
- The project has too little human data for a Nabla-style cloning stage.

## 2026-08-31: STEVE-1 and Video PreTraining

### Approach

- Video PreTraining (VPT) trains an inverse dynamics model (IDM) from video with
  actions. The IDM adds action labels to actionless video.
- A causal policy learns behavior cloning from frames and generated action
  labels.
- STEVE-1 adds visual-goal conditioning to VPT. Hindsight relabeling treats an
  achieved future state as the earlier goal.
- MineCLIP places text and video in one embedding space. A conditional
  variational autoencoder (CVAE) maps text to possible visual goals.

### Public Limits

- The VPT and STEVE-1 papers, source, and model weights are public.
- Full reproduction still needs large datasets, pretrained models, and large
  compute resources. The old dependency stack also makes execution fragile.
- MineCLIP publishes inference code and weights, but not its full training entry
  point.

### Useful Ideas for This Project

- Code-teacher trajectories have action records and do not need an IDM. An IDM
  is useful for valuable videos without action records.
- These trajectories can train a causal behavior-cloning baseline. Hindsight
  relabeling can turn achieved future states into short visual goals.
- Hindsight relabeling cannot add skills that the trajectories do not contain.
- The first goal experiment can use visual goals. Text conditioning can remain
  separate. A CVAE is useful for instructions with several valid visual goals.
- A recurrent baseline is smaller than a Transformer. Measured memory limits
  can justify a later Transformer experiment.
- Useful training data aligns each issued action with its source observation.
  It also records the actual application time.
- Privileged teacher state can supply labels and evaluation only. It cannot
  enter the deployed observation.

### Open Experiments

The project has not selected a goal encoder, goal horizon, frame history,
model, action distribution, loss, or text-conditioning method.

The first experiments can measure teacher reproduction, goal control, drift
recovery, and action-delay tolerance.

This research does not select VPT, MineCLIP, CVAE, IDM, a Transformer, or
reinforcement learning as a project dependency.

## Sources

- [STEVE-1](https://sites.google.com/view/steve-1)
- [STEVE-1 paper](https://proceedings.neurips.cc/paper_files/paper/2023/file/dd03f856fc7f2efeec8b1c796284561d-Paper-Conference.pdf)
- [STEVE-1 source](https://github.com/Shalev-Lifshitz/STEVE-1)
- [MineDojo and MineCLIP paper](https://arxiv.org/abs/2206.08853)
- [MineCLIP source](https://github.com/MineDojo/MineCLIP)
- [Video PreTraining paper](https://cdn.openai.com/vpt/Paper.pdf)
- [Video PreTraining source](https://github.com/openai/Video-Pre-Training)
- [Optimus-1](https://arxiv.org/abs/2408.03615)
- [Project reference catalog](../references.md)
