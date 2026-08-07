# Melin

Melin is the planning home for game features. It keeps product intent, implementation decisions, and near-term work together without turning every early idea into a rigid task list.

## Feature layout

Create one lowercase `snake_case` directory per feature under `features/`:

```text
features/<feature_name>/
  idea.md
  implementation.md
  tasks/
    active.md
    next.md
    archive/
```

- `idea.md` explains the player/developer problem, desired experience, constraints, and open questions.
- `implementation.md` records the agreed technical approach, affected systems, data flow, risks, and verification plan.
- `tasks/` uses rolling-wave planning: detailed work only for the next useful slice; later work remains outcome-focused until we learn more.

Start new features from `templates/feature/`.

## Working agreement

1. Discuss and record the idea before committing to an implementation.
2. Write a small implementation plan only after the goal and constraints are clear.
3. Create executable tasks only when they are ready to start.
4. Update the plan when reality changes; do not preserve stale plans for appearances.
5. Mark a task done only with proportionate verification recorded in the task.

The detailed rules live in [planning_rules.md](planning_rules.md) and [tooling_rules.md](tooling_rules.md).
