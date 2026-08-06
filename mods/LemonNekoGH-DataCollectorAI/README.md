# LemonNekoGH-DataCollectorAI

An AI mod that plays the game for collecting training data for AIRI.

## Structure

- `src/planner/index.ts` - Planner, generate plans to execute.
- `src/executor/task.ts` - Break the plan into executable tasks.
- `src/executor/action.ts` - Execute the `Quark Action` in the plan.

### Terms

- `Quark Action` - The basic action unit that can be executed by the AI,
  such as `move`, `pickup`, `interact`, etc. I don't want to use
  `Atomic Action` because the Atom is not the smallest unit in physics.
