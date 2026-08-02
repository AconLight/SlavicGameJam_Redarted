# Actor Pipeline Vertical Slice Report

## Implemented

- Godot editor addon at `addons/actor_pipeline` with a minimal creation dock.
- Typed actor resources: definition, animation contract, event set, sound set, generation manifest, and validation report.
- Shared `CharacterBody2D` template with visual, animator, animation-event, hitbox, and audio components.
- Safe `CHARACTER` factory with snake_case IDs, deterministic paths, conflict checks, and no overwrite path.
- Basic definition/event validator.
- Knight fixture generated from the supplied free pixel-art sheets.

## Verification

Godot 4.7.1 headless runs passed:

- `build_knight_fixture.gd` generated the actor resources and scene, locked the attack animation, and verified hitbox enable/disable events.
- `verify_knight_fixture.gd` loaded the generated actor, validated its resources, and repeated the runtime checks.

## Deliberately deferred

- Importing `.aseprite` directly: the addon consumes `SpriteFrames`; Aseprite Wizard remains the importer.
- Metadata refresh, complete validation suite, preview scene, sound fixture, and Inspector shortcuts.
- Archetypes other than `CHARACTER`.

## Fixture note

Two early failed fixtures are preserved in `actors/fixtures/` for debugging because this environment blocks recursive deletion. The current passing fixture is `actors/fixtures/knight/`.
