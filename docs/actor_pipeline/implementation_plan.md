# Actor Pipeline Implementation Plan

The original specification is preserved in `original_specification.md`. This plan narrows the delivery order so every stage can be verified in Godot before the next begins.

## Product boundary

This is a **Godot editor addon** at `addons/actor_pipeline`, not a Codex plugin. Its editor code creates and validates ordinary Godot scenes and resources. Generated actors remain usable if the editor addon is disabled.

## Phase 0 — Discovery and fixture input

- Confirm Godot 4.7.1, Aseprite Wizard 9.8.0, project conventions, and available assets.
- Let artists select an `.aseprite` source file in the addon and record that path as actor metadata.
- Do not create or depend on sample art fixtures; the pipeline begins once a project-owned source asset has been imported to `SpriteFrames`.
- Keep the pipeline independent of Aseprite parsing and of Aseprite Wizard internals.

## Phase 1 — Runtime vertical slice

- Implement typed actor resources: definition, animation contract, event set, sound set, and manifest.
- Implement one `CharacterBody2D` actor template with visual, animation, hitbox, event, and audio components.
- Prove semantic animation roles, attack locking, hitbox events, and sound-event validation using a manually authored fixture.

## Phase 2 — Safe actor factory

- Add the editor dock, request validation, deterministic paths, conflict checks, and resource/scene generation.
- Support only the `CHARACTER` archetype initially. Other archetypes remain visible but deliberately unavailable.
- Do not overwrite existing files and do not regenerate editable actor scenes.

## Phase 3 — Validation and refresh

- Validate actor, contract, events, and scene wiring.
- Add non-destructive animation-metadata refresh. It may update discovery fields and manifests only.

## Phase 4 — Preview and polish

- Add a reusable preview scene, frame stepping, event logging, collision overlays, and optional inspector shortcuts.

## Adjustments to the original scope

- Preview and metadata refresh are deferred until after the factory; they cannot be proven by Phases 0–2 alone.
- `AnimatedSprite2D.frame_changed` is the MVP event source. A later version must explicitly handle skipped-frame traversal.
- The runtime library stays in the addon, but only editor scripts require the addon to be enabled.
- One complete character is the acceptance target before additional archetypes or custom editor controls.
