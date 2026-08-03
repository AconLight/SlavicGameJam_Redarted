# Actor Pipeline: how it works

This document describes the addon that is currently in this repository: `addons/actor_pipeline`.

It is an editor helper, not a separate runtime framework. Its job is to turn one Aseprite file into a normal, editable Godot character scene plus a small set of Godot resources. After creation, the scene and resources are yours to edit normally.

## What the addon currently creates

Only one actor type exists today: `CHARACTER`.

It creates a `CharacterBody2D` scene with:

- an `AnimatedSprite2D` under `VisualRoot`;
- body collision, a hurtbox, and one disabled `primary_attack` hitbox;
- runtime helper nodes for visuals, animation roles, frame events, hitboxes, and audio.

It does not currently create AI, movement behavior, health logic, projectiles, interactions, or a preview window.

## Create flow

In the **Actor Pipeline** dock, fill in:

1. **Source Aseprite file** — an `.aseprite` or `.ase` file inside the Godot project, normally under `res://assets/...`.
2. **Actor ID** — lower snake case, for example `forest_boss`. It must start with a letter.
3. **Display name** — a human-readable name, for example `Forest Boss`.
4. **Output directory** — the exact folder where this actor's generated files go. The default is `res://actors`.

Then select **Create Character Actor**.

### Aseprite import behavior

The addon depends on the Aseprite Wizard addon and a working local Aseprite command path.

When the source already imports as `SpriteFrames`, the addon uses it immediately. When it is a newly discovered Aseprite file, Aseprite Wizard may initially assign its no-op importer. Actor Pipeline changes that file's `.import` settings to Aseprite Wizard's `SpriteFrames` importer, asks Godot to reimport it, waits for the result, and then creates the actor.

The source file and its adjacent `.aseprite.import` file should be committed in the assets repository. Do not commit the generated `.godot/` folder.

## Files generated

For actor ID `forest_boss` and output directory `res://actors/enemies/forest_boss`, the addon creates:

```text
actors/enemies/forest_boss/
  forest_boss.tscn
  forest_boss_definition.tres
  forest_boss_animation_contract.tres
  forest_boss_animation_events.tres
  forest_boss_sounds.tres
  forest_boss_generation_manifest.tres
```

The output directory is used directly. If the output is `res://actors`, the files are created directly inside `actors/`; it does not automatically make an additional actor-ID directory.

The factory refuses to overwrite any of these files. Choose a new directory or actor ID if a target already exists.

## What each generated resource is for

| File | Purpose | Safe to edit manually? |
| --- | --- | --- |
| `*_definition.tres` | Actor identity, source path, SpriteFrames link, gameplay defaults, and links to the other actor resources. | Yes |
| `*_animation_contract.tres` | Maps actual animation names to semantic roles such as `locomotion.idle` and `combat.attack.primary`. | Yes |
| `*_animation_events.tres` | Frame-based hitbox, sound, completion, and custom events. | Yes |
| `*_sounds.tres` | Named sound entries, streams, volume, pitch range, and audio bus. | Yes |
| `*_generation_manifest.tres` | A record of discovered animation names, frame counts, looping, and source fingerprint. | Normally leave it alone |
| `*.tscn` | The editable actor scene and its collision/runtime node wiring. | Yes |

## Automatic animation mapping

The importer reads every animation in the source `SpriteFrames` resource and creates a contract entry for it.

These names receive a semantic role automatically, case-insensitively:

| Animation name | Role |
| --- | --- |
| `Idle` | `locomotion.idle` |
| `Walk` | `locomotion.walk` |
| `Run` | `locomotion.run` |
| `Hurt` or `Damage` | `damage.hurt` |
| `Death` or `Die` | `lifecycle.death` |
| `Attack`, `Attack_1`, or `Attack_Primary` | `combat.attack.primary` |

The generated scene selects the mapped idle animation for its editor-visible `AnimatedSprite2D` when available. It does not guess semantic roles for names outside this list; edit the animation contract if your asset uses different naming.

## Runtime behavior already included

`ActorBase` loads the definition at runtime and connects the generated components.

- `ActorAnimator` plays a semantic role or an animation name and can lock an attack until it finishes.
- `ActorAnimationEventPlayer` watches `AnimatedSprite2D.frame_changed` and dispatches events for that frame.
- `HitboxController` enables or disables a hitbox using the event's target ID. The template's initial target is `primary_attack`.
- `ActorAudioController` plays a named sound entry through `EventAudioPlayer`.

Supported animation event types are:

- `HITBOX_ENABLE`
- `HITBOX_DISABLE`
- `PLAY_SOUND`
- `ACTION_COMPLETE`
- `CUSTOM` — emits `custom_event_triggered(event_id, payload)` for your own game code to handle.

Events can be configured to fire once per playback. The current MVP relies on `frame_changed`, so it does not yet handle every possible skipped-frame case from abrupt animation changes.

## What you edit after creation

The normal workflow is:

1. Generate the actor.
2. Open the `.tscn` and adjust collision shapes, hitbox position, node transforms, and any gameplay scripts.
3. Open the animation contract and correct/add semantic roles as needed.
4. Add events at exact animation frames in the event resource.
5. Add `AudioStream` files to the sound resource and connect sound events by matching `target_id` to `sound_id`.
6. Save and commit the actor scene/resources in the main game repository.

The addon does not currently regenerate existing actors. This protects manual edits, but it also means Aseprite changes do not automatically refresh an existing actor's animation contract or manifest.

## Lighting-map workflow

Lighting is optional. In **None** mode, actor generation behaves as it did before lighting maps existed.

The Actor Pipeline offers three map sources:

- **None**: creates an unlit actor.
- **From Lighting Folder**: finds maps beside the Aseprite source automatically. The expected names are `<source>_lighting_reference_n.png` (normal), `_s.png` (specular), `_o.png` (occlusion), and optional `_e.png` (emission).
- **Auto (Laigter Defaults)**: exports the reference sheet, then runs Laigter without its GUI to generate normal, specular, and occlusion maps with Laigter's default settings. Configure the path to `laigter.exe` once in the dock.

For either lighting mode, maps are made from the exact reference sheet and are stored in the source asset's `lighting/` directory. Do not trim, repack, rotate, pad, or resize them.

The normal map is required. All discovered maps must be project-local textures and exactly match the exported reference dimensions. The source Aseprite fingerprint must still match the reference metadata; if the source art changed, export a new reference and regenerate the maps.

The lighting reference sheet is exported as an RGBA PNG with a transparent background. Do not flatten it or add a matte color before opening it in Laigter or another map-authoring tool.

The generated rendering profile stores every discovered map, and the normal map is assigned to the generated `AnimatedSprite2D`. A game-specific shader/material can additionally consume the saved specular, occlusion, and emission maps at runtime.

## Current limitations

- `CHARACTER` is the only supported archetype.
- No actor preview, frame-step tool, event log, collision overlay, or custom Inspector controls.
- No metadata refresh for existing actors after an Aseprite file changes.
- No UI for assigning sound folders or sound files; edit `*_sounds.tres` manually.
- Validation code exists, but the dock has no **Validate Actor** button yet.
- The addon has no automatic AI, movement, health, projectile, NPC, pickup, or prop templates.

## Repository split

For this project:

- Aseprite, audio, fonts, exports, and third-party packs live in the separate `assets` repository/submodule.
- Actor scenes and `.tres` resources generated under `actors/` live in the main game repository.
- A source asset's `.import` file also belongs in the assets repository because it records the chosen Godot importer and its settings.
