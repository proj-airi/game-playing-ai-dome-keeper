# Continuous Self-Learning Experiment

**Status: non-binding personal dream outside project scope, architecture, and
roadmap.** There is no commitment or authorization to implement it, and it must
not influence present project work.

One possible independent research exploration could examine a bounded offline
system that evaluates gameplay, Vision, teacher, and Lower Agent variants and
proposes improvements. Possible safeguards could include explicit budgets,
reproducible runs, fixed comparison baselines, protected evaluation data, and
manual approval gates. These are exploratory notes, not requirements.

## Possible TODO: Parallel Branching Rollouts

- Explore a bounded local experiment that runs many isolated game instances in
  parallel so strategy variants can produce evidence faster. Give every
  instance independent disposable writable state that never touches normal user
  profiles or saves, preserve a distinct rollout lineage and failed
  trajectories, and measure actual throughput against CPU, GPU, memory, and
  rendering contention rather than assuming linear scaling.
- Explore restorable experimental checkpoints at selected decision points. When
  a rollout fails, retain that failure and branch alternative strategies from a
  preceding checkpoint instead of erasing or overwriting the original
  trajectory. Call it a restorable snapshot only after defining its consistency
  boundary and empirically measuring restore fidelity across random sources,
  world and physics objects, wave timing, inventory and upgrades, modal and
  input state, and controller state. Treat divergence as expected evidence, not
  as exact deterministic continuation; otherwise restart from a supported save
  or replay the action prefix and label the result accordingly.
- Keep checkpoint lineage, policy version, experiment inputs, and branch
  identity explicit, and validate promising branches in fresh complete runs so
  repeated restoration does not become the evaluation distribution. Any
  snapshot or process-level restoration remains privileged, machine-local
  experiment orchestration for an owned game; it is not a deployed Agent action
  or permission to consume privileged state during deployed control. Never
  distribute snapshots containing game state or assets.

Do not reserve interfaces, add dependencies, collect extra data, constrain the
teacher or Agent contracts, define promotion metrics, or change architecture for
this dream. If the user explicitly revives it, design it anew from the project's
then-current evidence.

Possible background reading, relevant only to this dream:

- [MLflow Tracking](https://mlflow.org/docs/latest/tracking/)
- [Ultralytics Hyperparameter Tuning](https://docs.ultralytics.com/guides/hyperparameter-tuning)
- [Gymnasium: Speeding Up Training](https://gymnasium.farama.org/main/introduction/speed_up_env/)
- [First return, then explore](https://arxiv.org/abs/2004.12919)
- [Godot 4.3: Saving games](https://docs.godotengine.org/en/4.3/tutorials/io/saving_games.html)
