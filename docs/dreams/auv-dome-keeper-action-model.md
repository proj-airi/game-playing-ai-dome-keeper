# Action-Model-Driven AUV Dome Keeper

**Status: non-binding personal dream outside project scope, architecture, and
roadmap.** There is no commitment or authorization to implement it, and it
must not influence present project work.

One possible future direction is for `auv-dome-keeper` to use the gameplay
action model trained from the DataCollectorAI work as its primary Dome Keeper
control mechanism. The AUV integration would consume the model's observation
and action interfaces instead of requiring a general-purpose Godot debugging
connection.

The `godot-remote-debugger` / `vidot` / Godot-specific AUV adapter stack is
intentionally deferred here. It is a much larger and more general project than
the immediate game-internal testing work, and should not be treated as a
prerequisite for `vikeeper`, DataCollectorAI, or the first `auv-dome-keeper`
experiments.

When this dream is revived, revisit from the then-current action-model
contract. Decide how AUV supplies observations, requests model actions,
handles model lifecycle, and verifies the resulting game behavior. Do not
reserve interfaces, add dependencies, or redesign the current runtime for this
dream in advance.

Background: [AUV repository](https://github.com/moeru-ai/auv).
