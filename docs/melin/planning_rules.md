# Melin Planning Rules

## Feature documents

Each feature directory owns its decisions. Do not mix feature-specific notes into global rules.

`idea.md` should answer:

- What problem are we solving, and for whom?
- What does success look and feel like?
- What is explicitly out of scope?
- Which decisions are open or need a prototype?

`implementation.md` should answer:

- Which scenes, scripts, resources, assets, and tools change?
- What is the smallest viable technical approach?
- What are the main risks, assumptions, and rollback points?
- How will we verify the feature in Godot?

## Rolling-wave tasks

Use three horizons:

- `active.md`: one concrete task currently being executed. It includes scope, acceptance checks, files/systems touched, and verification.
- `next.md`: the next one to three tasks, described enough to start after the active task. They may change.
- `archive/`: completed or abandoned task records, with the outcome and any decision that changed the later plan.

Do not create detailed tasks for uncertain future work. Keep those as short outcome bullets in `implementation.md` until the preceding work reveals the right path.

When a task finishes:

1. Record what changed and how it was verified.
2. Move it to `archive/`.
3. Promote, split, remove, or rewrite only the next useful task.
4. Update `idea.md` or `implementation.md` if the discovery affects the feature decision.

## Ready and done

A task is ready when its goal, boundary, acceptance checks, and immediate dependencies are known.

A task is done when the requested behavior is implemented, relevant checks pass, and any important limitation is recorded. A passing parser alone is not sufficient for visible gameplay behavior; run the relevant scene when practical.
