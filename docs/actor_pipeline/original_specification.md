# Godot Actor Asset Pipeline

## Codex Implementation Specification

## 1. Objective

Create a Godot editor plugin that converts an Aseprite-imported `SpriteFrames` resource into a reusable, editable, validated game actor.

The plugin must generate the repetitive structure required for an animated game object while preserving all subsequent manual edits.

The initial pipeline is:

```text
Aseprite file
    ↓
Aseprite Wizard imports SpriteFrames
    ↓
Developer selects SpriteFrames
    ↓
Actor Pipeline creates actor definition and scene
    ↓
Developer edits hitboxes, sounds and events normally
    ↓
Validator checks configuration
    ↓
Preview scene runs the actor
```

The plugin is not responsible for drawing, modifying or parsing `.aseprite` files.

The plugin operates on the imported `SpriteFrames` resource produced by Aseprite Wizard.

---

# 2. MVP scope

The first implementation should support:

* creating an actor from an imported `SpriteFrames`;
* selecting an actor archetype;
* generating an editable actor scene;
* generating an `ActorDefinition` resource;
* generating editable animation-event resources;
* mapping Aseprite tags to Godot animations;
* manually editable body collider, hurtbox and attack hitbox;
* frame-based sound events;
* frame-based hitbox events;
* locked and interruptible animations;
* animation validation;
* event validation;
* a reusable actor preview scene;
* safe regeneration of generated visual metadata;
* running automated validation through Godot headless mode.

The MVP must not include:

* a custom timeline editor;
* waveform display;
* automatic hitbox extraction from sprite pixels;
* automatic animation-event migration;
* per-frame polygon hitboxes;
* automatic AI-generated behavior;
* automatic sound selection;
* direct editing of `.aseprite` binary files;
* fully autonomous scene composition;
* automatic modification of manually edited actor scenes.

---

# 3. Design principles

## 3.1 Generated structure, editable configuration

The generator creates structure and initial defaults.

The user remains able to edit:

* hitbox positions;
* hitbox shapes;
* body collision;
* sounds;
* event frames;
* event parameters;
* animation behavior;
* custom nodes;
* custom scripts;
* actor statistics;
* collision layers and masks.

## 3.2 Never overwrite manual work

Generated and user-owned data must be clearly separated.

The plugin may safely update:

* discovered animation names;
* animation frame counts;
* imported `SpriteFrames` reference;
* validation reports;
* generated preview metadata;
* generation timestamps and source hashes.

The plugin must not overwrite:

* manually positioned hitboxes;
* manually assigned sounds;
* manually authored events;
* actor statistics;
* scene overrides;
* user-added nodes;
* custom scripts;
* collision settings;
* effect assignments.

## 3.3 Ordinary Godot objects first

The plugin must use normal Godot objects wherever practical:

* `CharacterBody2D`;
* `AnimatedSprite2D`;
* `AnimationPlayer`;
* `Area2D`;
* `CollisionShape2D`;
* `AudioStreamPlayer2D`;
* custom `Resource` definitions.

A developer should be able to disable the plugin and continue using generated actors.

## 3.4 Configuration over generated scripts

Do not generate one custom script per actor unless explicitly required.

Prefer:

```text
shared runtime scripts
+
actor-specific Resource configuration
+
actor-specific scene overrides
```

## 3.5 Stable identifiers

Events and bindings must use stable IDs rather than array positions.

Example:

```text
attack_primary.hitbox.enable
attack_primary.hitbox.disable
walk.footstep.left
walk.footstep.right
death.finished
```

Array order must not define identity.

---

# 4. Ownership model

Every file or property belongs to one of three ownership categories.

## 4.1 Plugin-owned

The plugin may regenerate this data.

Examples:

* animation discovery cache;
* generated validation report;
* generated preview actor instance;
* source resource path;
* source fingerprint;
* generated default event suggestions that were not accepted.

## 4.2 User-owned

The plugin must never overwrite this data.

Examples:

* sound assignments;
* hitbox geometry;
* event timing;
* actor stats;
* manual scene children;
* collision layers;
* custom behavior;
* effect assignments.

## 4.3 Shared ownership

The plugin may update only specifically documented fields.

Example:

```text
AnimationContractEntry
- animation_name: plugin-maintained discovery
- required: user-maintained
- looping_policy: user-maintained
- last_seen_frame_count: plugin-maintained
```

Ownership rules must be documented in code comments.

---

# 5. High-level architecture

```text
addons/actor_pipeline/
│
├── plugin.cfg
├── actor_pipeline_plugin.gd
│
├── editor/
│   ├── actor_creation_dialog.gd
│   ├── actor_creation_dialog.tscn
│   ├── actor_pipeline_dock.gd
│   ├── actor_pipeline_dock.tscn
│   ├── actor_definition_inspector.gd
│   └── validation_results_panel.gd
│
├── domain/
│   ├── actor_definition.gd
│   ├── actor_archetype.gd
│   ├── animation_contract.gd
│   ├── animation_contract_entry.gd
│   ├── animation_event.gd
│   ├── animation_event_set.gd
│   ├── actor_sound_set.gd
│   ├── actor_generation_manifest.gd
│   ├── validation_issue.gd
│   └── validation_report.gd
│
├── generation/
│   ├── actor_factory.gd
│   ├── actor_scene_builder.gd
│   ├── actor_definition_builder.gd
│   ├── animation_contract_builder.gd
│   ├── preview_scene_builder.gd
│   ├── path_policy.gd
│   └── generation_result.gd
│
├── validation/
│   ├── actor_validator.gd
│   ├── animation_contract_validator.gd
│   ├── animation_event_validator.gd
│   ├── actor_scene_validator.gd
│   └── validation_runner.gd
│
├── runtime/
│   ├── actor_animator.gd
│   ├── actor_animation_event_player.gd
│   ├── actor_audio_controller.gd
│   ├── hitbox_controller.gd
│   ├── actor_visual_controller.gd
│   └── actor_base.gd
│
├── templates/
│   ├── actor_base.tscn
│   ├── character_actor.tscn
│   ├── animated_decoration.tscn
│   ├── projectile.tscn
│   └── actor_preview.tscn
│
├── tests/
│   ├── fixtures/
│   ├── test_actor_factory.gd
│   ├── test_animation_contract.gd
│   ├── test_animation_events.gd
│   ├── test_safe_regeneration.gd
│   └── test_actor_preview.gd
│
└── README.md
```

For the first implementation, unnecessary empty files may be omitted, but responsibilities must remain separated.

---

# 6. Core domain contracts

## 6.1 ActorDefinition

```gdscript
@tool
class_name ActorDefinition
extends Resource

@export_group("Identity")
@export var actor_id: StringName
@export var display_name: String
@export var archetype: ActorArchetype.Type

@export_group("Source")
@export var sprite_frames: SpriteFrames
@export_file("*.ase", "*.aseprite") var source_aseprite_path: String
@export var generation_manifest: ActorGenerationManifest

@export_group("Animation")
@export var animation_contract: AnimationContract
@export var animation_events: AnimationEventSet

@export_group("Audio")
@export var sound_set: ActorSoundSet

@export_group("Gameplay Defaults")
@export var maximum_health: float = 100.0
@export var movement_speed: float = 100.0
@export var contact_damage: float = 0.0

@export_group("Scene")
@export_file("*.tscn") var generated_scene_path: String
@export_file("*.tscn") var editable_scene_path: String
```

Rules:

* `actor_id` is stable and unique.
* `sprite_frames` is required.
* `source_aseprite_path` is informational and must not be parsed by the MVP.
* runtime code consumes this resource;
* editor-generation details that runtime does not need should go into the manifest.

---

## 6.2 ActorArchetype

```gdscript
class_name ActorArchetype
extends RefCounted

enum Type {
    CHARACTER,
    GROUND_ENEMY,
    FLYING_ENEMY,
    PROJECTILE,
    DESTRUCTIBLE_PROP,
    ANIMATED_DECORATION,
    COLLECTIBLE
}
```

MVP implementation requirements:

* fully support `CHARACTER`;
* support `ANIMATED_DECORATION`;
* allow other enum values but mark unfinished templates clearly.

Do not implement seven distinct complex templates during the MVP.

---

## 6.3 AnimationContract

```gdscript
@tool
class_name AnimationContract
extends Resource

@export var entries: Array[AnimationContractEntry] = []
```

```gdscript
@tool
class_name AnimationContractEntry
extends Resource

enum LoopPolicy {
    FROM_SOURCE,
    FORCE_LOOP,
    FORCE_NO_LOOP
}

enum InterruptionPolicy {
    INTERRUPTIBLE,
    LOCK_UNTIL_FINISHED,
    NEVER_INTERRUPT
}

@export var animation_name: StringName
@export var required: bool = false
@export var semantic_role: StringName
@export var loop_policy: LoopPolicy = LoopPolicy.FROM_SOURCE
@export var interruption_policy: InterruptionPolicy = \
    InterruptionPolicy.INTERRUPTIBLE

@export_group("Generated Metadata")
@export var last_seen_frame_count: int
@export var last_seen_speed_fps: float
```

Suggested semantic roles:

```text
locomotion.idle
locomotion.walk
locomotion.run
air.jump
air.fall
combat.attack.primary
damage.hurt
lifecycle.death
```

Gameplay should request semantic roles where possible.

The actual Aseprite tag remains configurable.

Example:

```text
semantic_role = combat.attack.primary
animation_name = sword_attack_01
```

This prevents game code from becoming coupled to one naming convention.

---

## 6.4 AnimationEvent

```gdscript
@tool
class_name AnimationEvent
extends Resource

enum EventType {
    HITBOX_ENABLE,
    HITBOX_DISABLE,
    PLAY_SOUND,
    SPAWN_EFFECT,
    SPAWN_PROJECTILE,
    EMIT_SIGNAL,
    ACTION_COMPLETE,
    CAMERA_SHAKE,
    CUSTOM
}

@export var event_id: StringName
@export var enabled: bool = true

@export_group("Trigger")
@export var animation_role: StringName
@export var animation_name_override: StringName
@export_range(0, 999, 1) var frame: int = 0
@export var fire_once_per_playback: bool = true

@export_group("Action")
@export var event_type: EventType
@export var target_id: StringName
@export var payload: Dictionary = {}
```

Rules:

* `event_id` must be unique within an actor.
* Use `animation_role` by default.
* `animation_name_override` is optional.
* `frame` refers to the current animation-local frame.
* runtime must not depend on array index.
* invalid events are reported, not silently deleted.

Examples:

```text
event_id: attack_primary.hitbox.enable
animation_role: combat.attack.primary
frame: 2
event_type: HITBOX_ENABLE
target_id: primary_attack
```

```text
event_id: attack_primary.swing_sound
animation_role: combat.attack.primary
frame: 1
event_type: PLAY_SOUND
target_id: attack_swing
```

---

## 6.5 AnimationEventSet

```gdscript
@tool
class_name AnimationEventSet
extends Resource

@export var events: Array[AnimationEvent] = []
```

Required helper API:

```gdscript
func get_events_for_frame(
    animation_name: StringName,
    semantic_role: StringName,
    frame: int
) -> Array[AnimationEvent]
```

The first version may perform a simple scan.

Do not optimize prematurely.

---

## 6.6 ActorSoundSet

```gdscript
@tool
class_name ActorSoundSet
extends Resource

@export var sounds: Array[ActorSoundEntry] = []
```

```gdscript
@tool
class_name ActorSoundEntry
extends Resource

@export var sound_id: StringName
@export var streams: Array[AudioStream] = []
@export_range(-80.0, 24.0, 0.1) var volume_db: float = 0.0
@export_range(0.1, 4.0, 0.01) var pitch_min: float = 1.0
@export_range(0.1, 4.0, 0.01) var pitch_max: float = 1.0
@export var bus: StringName = &"SFX"
```

The audio controller chooses one stream from `streams`.

An empty stream list is a validation warning or error depending on whether an enabled event references it.

---

## 6.7 ActorGenerationManifest

```gdscript
@tool
class_name ActorGenerationManifest
extends Resource

@export var generator_version: String
@export var actor_id: StringName
@export var source_resource_path: String
@export var source_fingerprint: String
@export var generated_at_unix: int
@export var discovered_animations: Array[StringName]
@export var discovered_frame_counts: Dictionary
```

The manifest supports regeneration and diagnostics.

It must never be treated as authoritative gameplay data.

---

# 7. Generated actor scene

The default generated actor scene should resemble:

```text
ActorBase
├── VisualRoot
│   └── AnimatedSprite2D
│
├── BodyCollision
│   └── CollisionShape2D
│
├── Hurtboxes
│   └── PrimaryHurtbox
│       └── CollisionShape2D
│
├── Hitboxes
│   └── PrimaryAttack
│       └── CollisionShape2D
│
├── Components
│   ├── ActorVisualController
│   ├── ActorAnimator
│   ├── AnimationEventPlayer
│   ├── HitboxController
│   └── ActorAudioController
│
├── Audio
│   └── EventAudioPlayer
│
└── Effects
```

For a moving character, `ActorBase` may be `CharacterBody2D`.

For a decoration, it may be `Node2D`.

## Required node groups

Add predictable groups:

```text
actor
actor_visual
actor_hurtbox
actor_hitbox
actor_audio
```

## Required metadata

The root node should contain:

```gdscript
set_meta(&"actor_pipeline_id", actor_definition.actor_id)
set_meta(&"actor_pipeline_version", GENERATOR_VERSION)
```

Metadata is for diagnostics only.

---

# 8. Generated versus editable scene strategy

## Recommended MVP strategy

Generate one normal editable scene:

```text
actors/slime/slime.tscn
```

Do not automatically regenerate it after creation.

Store all changeable animation metadata in external resources:

```text
actors/slime/slime_definition.tres
actors/slime/slime_animation_contract.tres
actors/slime/slime_animation_events.tres
actors/slime/slime_sounds.tres
```

When Aseprite changes, update the `SpriteFrames` through Aseprite Wizard and run validation.

The user manually requests:

```text
Refresh animation metadata
```

This refresh updates only:

* discovered animation list;
* frame counts;
* source fingerprint;
* validation information.

This strategy is safer than trying to regenerate scenes automatically.

## Later strategy

A future version may use:

```text
slime_generated.tscn
    ↓ inherited by
slime.tscn
```

Do not implement inherited generated scenes in the first version unless Codex can prove regeneration preserves overrides through automated tests.

---

# 9. Runtime components

## 9.1 ActorVisualController

Responsibilities:

* own the `AnimatedSprite2D` reference;
* apply `SpriteFrames`;
* set horizontal facing;
* expose animation and frame information;
* avoid flipping the physical actor root.

Public API:

```gdscript
signal animation_changed(animation_name: StringName)
signal animation_frame_changed(
    animation_name: StringName,
    frame: int
)

func set_sprite_frames(value: SpriteFrames) -> void
func set_facing(direction: float) -> void
func get_current_animation() -> StringName
func get_current_frame() -> int
```

---

## 9.2 ActorAnimator

Responsibilities:

* resolve semantic animation roles;
* play animations;
* enforce interruption policies;
* report completion;
* remain independent of gameplay state logic.

Public API:

```gdscript
signal animation_started(
    semantic_role: StringName,
    animation_name: StringName
)

signal animation_finished(
    semantic_role: StringName,
    animation_name: StringName
)

func play_role(
    semantic_role: StringName,
    restart: bool = false
) -> bool

func play_animation(
    animation_name: StringName,
    restart: bool = false
) -> bool

func force_play_role(semantic_role: StringName) -> bool
func unlock() -> void
func is_locked() -> bool
func has_role(semantic_role: StringName) -> bool
```

Rules:

* locomotion animations are normally interruptible;
* attack, hurt and death may lock playback;
* death should normally have the strongest lock;
* no gameplay logic should depend directly on sprite frame indices.

---

## 9.3 ActorAnimationEventPlayer

Responsibilities:

* observe animation start and frame changes;
* dispatch matching events;
* prevent duplicate execution;
* reset fired-event state on animation restart;
* emit generic event signals;
* delegate sound and hitbox actions.

Public API:

```gdscript
signal event_triggered(event: AnimationEvent)
signal custom_event_triggered(
    event_id: StringName,
    payload: Dictionary
)

func bind(
    animator: ActorAnimator,
    event_set: AnimationEventSet
) -> void

func reset_playback_state() -> void
```

Important cases:

* animation starts on frame zero;
* animation loops;
* frames are skipped due to low frame rate;
* animation restarts;
* event is disabled;
* event frame is outside current animation range.

For the MVP, process `AnimatedSprite2D.frame_changed`.

Document that skipped-frame robustness may require later improvement.

---

## 9.4 HitboxController

Responsibilities:

* resolve hitboxes by stable ID;
* enable or disable attack areas;
* default all attack hitboxes to disabled;
* avoid changing shapes or positions.

Each hitbox should carry:

```gdscript
@export var hitbox_id: StringName
```

Public API:

```gdscript
func enable_hitbox(hitbox_id: StringName) -> bool
func disable_hitbox(hitbox_id: StringName) -> bool
func disable_all_hitboxes() -> void
func has_hitbox(hitbox_id: StringName) -> bool
```

Implementation must support whichever `Area2D` setting the project chooses for activation:

* `monitoring`;
* collision-layer state;
* shape disabled state.

Choose one approach and document it.

Recommended MVP:

```text
CollisionShape2D.disabled
```

Use deferred property changes where required by Godot physics.

---

## 9.5 ActorAudioController

Responsibilities:

* resolve sound entries by stable ID;
* choose a stream;
* apply volume, bus and randomized pitch;
* play through an internal `AudioStreamPlayer2D`.

Public API:

```gdscript
func play_sound(sound_id: StringName) -> bool
func has_sound(sound_id: StringName) -> bool
func stop() -> void
```

Do not create one audio node per event in the MVP.

---

# 10. Editor plugin interface

## 10.1 Main dock

Add an `Actor Pipeline` dock containing:

```text
Source SpriteFrames: [resource picker]
Actor ID:             [text field]
Display Name:         [text field]
Archetype:            [dropdown]
Output Directory:     [path field]

[Create Actor]
[Refresh Metadata]
[Validate Selected Actor]
[Open Preview]
[Validate All Actors]
```

## 10.2 Creation dialog

When the user selects `Create Actor`, validate:

* `SpriteFrames` is assigned;
* actor ID is non-empty;
* actor ID contains only allowed characters;
* output directory is valid;
* target files do not already exist.

If target files exist, show options:

```text
Cancel
Open Existing
Create With New Name
```

Do not provide a destructive overwrite option in the MVP.

## 10.3 Inspector integration

When an `ActorDefinition` is selected, show an Inspector section containing:

```text
Open Actor Scene
Open Preview
Refresh Animation Metadata
Validate Actor
```

A custom Inspector plugin is optional for the first version.

The dock is sufficient initially.

---

# 11. Actor creation workflow

## Input

```text
SpriteFrames resource
Actor ID
Display name
Archetype
Output directory
```

## Process

1. Validate input.
2. Inspect `SpriteFrames.get_animation_names()`.
3. Read frame counts, speed and loop state.
4. Create an `AnimationContract`.
5. Apply known tag-name suggestions.
6. Create an empty `AnimationEventSet`.
7. Create an empty `ActorSoundSet`.
8. Create an `ActorDefinition`.
9. Instantiate the selected actor template.
10. Assign resources to the template.
11. Assign default collision shapes.
12. Disable attack hitboxes.
13. Save the scene and resources.
14. Generate the manifest.
15. Validate the result.
16. Open the generated actor scene.
17. Report created files and warnings.

## Default role suggestions

Use exact-name suggestions only:

```text
idle        → locomotion.idle
walk        → locomotion.walk
run         → locomotion.run
jump        → air.jump
fall        → air.fall
attack      → combat.attack.primary
hurt        → damage.hurt
death       → lifecycle.death
```

Also recognize optional aliases:

```text
attack_1
attack_primary
light_attack
die
dead
damage
walk_loop
idle_loop
```

Aliases are suggestions, not unquestionable mappings.

Ambiguous mappings must be reported for user review.

---

# 12. Manual hitbox editing

The generated scene must expose normal `CollisionShape2D` nodes.

The user changes hitboxes by:

1. opening the actor scene;
2. selecting a hitbox;
3. moving or resizing its shape in the 2D editor;
4. saving the scene.

The plugin must not copy hitbox transforms into generated metadata.

The event resource controls only:

```text
which hitbox
when to enable it
when to disable it
```

The scene controls:

```text
where it is
what shape it has
which collision layers it uses
```

This separation is mandatory.

---

# 13. Manual sound-event editing

Sound definitions are edited through `ActorSoundSet`.

Animation-event timing is edited through `AnimationEventSet`.

Example:

```text
ActorSoundSet
└── attack_swing
    ├── sword_swing_01.wav
    ├── sword_swing_02.wav
    ├── volume_db = -2.0
    ├── pitch_min = 0.95
    └── pitch_max = 1.05
```

```text
AnimationEventSet
└── attack_primary.swing_sound
    ├── animation_role = combat.attack.primary
    ├── frame = 2
    ├── event_type = PLAY_SOUND
    └── target_id = attack_swing
```

Changing the animation event must not modify the sound set.

Changing the sound set must not modify animation timing.

---

# 14. Regeneration contract

## Refresh Animation Metadata

This command may:

* update discovered animations;
* update frame counts;
* update source loop state;
* add newly discovered animations to the contract;
* mark missing source animations as unavailable;
* recalculate validation issues;
* update manifest metadata.

It must not:

* remove contract entries automatically;
* remove animation events;
* shift animation event frames;
* modify hitboxes;
* modify sounds;
* recreate the actor scene;
* overwrite semantic mappings;
* overwrite user interruption policies.

## Missing animation behavior

Suppose `attack` existed previously and is later renamed.

The plugin should report:

```text
ERROR:
Animation role combat.attack.primary refers to missing animation "attack".

Possible new animation:
"attack_primary"
```

It must not silently remap it.

## Frame-count change behavior

Suppose an animation changes from six frames to four and an event remains at frame five.

Report:

```text
ERROR:
Event attack_primary.hitbox.disable targets frame 5,
but animation attack now has frames 0–3.
```

Do not clamp or move the event automatically.

---

# 15. Validation system

## Severity

```gdscript
enum Severity {
    INFO,
    WARNING,
    ERROR
}
```

## ValidationIssue

```gdscript
@tool
class_name ValidationIssue
extends Resource

@export var severity: Severity
@export var code: StringName
@export var message: String
@export var resource_path: String
@export var property_path: String
@export var suggested_action: String
```

## Required validation rules

### Actor definition

* actor ID is empty;
* actor ID is duplicated;
* `SpriteFrames` is missing;
* actor scene path is invalid;
* definition points to missing resources.

### Animation contract

* required semantic role is missing;
* mapped animation does not exist;
* duplicate semantic role;
* duplicate animation mapping;
* death animation loops unexpectedly;
* locked animation has no finish path;
* zero-frame animation.

### Animation events

* duplicate event ID;
* event refers to missing semantic role;
* event refers to missing animation;
* frame is negative;
* frame is outside animation range;
* target hitbox does not exist;
* target sound does not exist;
* enabled sound event has no assigned stream;
* hitbox enable has no corresponding disable;
* attack ends while a hitbox may remain enabled.

### Actor scene

* required node is missing;
* runtime component reference is missing;
* visual sprite has no `SpriteFrames`;
* hitbox starts enabled;
* audio player is missing;
* duplicate hitbox ID;
* body collider has no shape;
* definition does not match actor scene.

## Validation output

Display:

```text
[ERROR] 3
[WARNING] 5
[INFO] 2
```

Each issue should include:

* actor name;
* issue code;
* explanation;
* suggested action;
* resource or scene path.

---

# 16. Preview system

Create one shared preview scene:

```text
addons/actor_pipeline/templates/actor_preview.tscn
```

It should allow the user to:

* select an actor definition;
* instantiate the actor;
* select an animation role;
* play, pause and restart;
* advance one frame;
* toggle hitbox visualization;
* toggle hurtbox visualization;
* display the current frame;
* display triggered events;
* display current lock state;
* trigger sound events;
* change playback speed;
* flip actor direction.

The preview scene must not duplicate actor resources.

It consumes an `ActorDefinition`.

## Preview UI

```text
Actor: [definition]

Animation: [dropdown]
[Play] [Pause] [Restart] [Previous Frame] [Next Frame]

Playback speed: [slider]
Facing: [Left] [Right]

[✓] Show body collision
[✓] Show hurtboxes
[✓] Show hitboxes
[✓] Log events

Current animation:
Current frame:
Current semantic role:
Animator locked:
Last event:
```

For the MVP, opening the preview may run the preview scene as the project’s current scene through an editor action or instantiate it in a dedicated test scene.

---

# 17. Plugin API boundaries

## ActorFactory

```gdscript
class_name ActorFactory
extends RefCounted

func create_actor(request: ActorCreationRequest) -> GenerationResult
func refresh_metadata(definition: ActorDefinition) -> GenerationResult
```

## ActorCreationRequest

```gdscript
class_name ActorCreationRequest
extends RefCounted

var sprite_frames: SpriteFrames
var source_aseprite_path: String
var actor_id: StringName
var display_name: String
var archetype: ActorArchetype.Type
var output_directory: String
```

## GenerationResult

```gdscript
class_name GenerationResult
extends RefCounted

var success: bool
var created_paths: PackedStringArray
var warnings: PackedStringArray
var errors: PackedStringArray
var actor_definition: ActorDefinition
var actor_scene: PackedScene
```

No generation method should throw on expected user input errors.

Return structured failures.

---

# 18. File-naming contract

Given:

```text
actor_id = slime
output_directory = res://actors/enemies/slime
```

Generate:

```text
res://actors/enemies/slime/slime.tscn
res://actors/enemies/slime/slime_definition.tres
res://actors/enemies/slime/slime_animation_contract.tres
res://actors/enemies/slime/slime_animation_events.tres
res://actors/enemies/slime/slime_sounds.tres
res://actors/enemies/slime/slime_generation_manifest.tres
```

Rules:

* actor IDs use `snake_case`;
* type names use `PascalCase`;
* generated files must have deterministic names;
* no GUID-like names;
* no silent filename suffixes;
* existing file conflicts must stop generation.

---

# 19. Error-handling requirements

The plugin must:

* use `push_error` only for unexpected internal failures;
* display ordinary validation failures in the plugin UI;
* never partially overwrite an existing actor;
* clean up newly created files if generation fails;
* verify `ResourceSaver.save()` results;
* verify `PackedScene.pack()` results;
* rescan the editor filesystem after generation;
* provide actionable messages.

Generation should ideally be transactional:

```text
validate request
→ construct in memory
→ save temporary/new resources
→ save scene
→ verify load
→ report success
```

Because Godot does not provide a full filesystem transaction, keep creation order safe and clean up partial results on failure.

---

# 20. Testing strategy

## Unit tests

Test pure logic separately:

* role-name inference;
* duplicate event detection;
* out-of-range frame detection;
* stable event IDs;
* path generation;
* manifest generation;
* metadata refresh behavior.

## Integration tests

Create fixture `SpriteFrames` resources programmatically.

Do not require Aseprite to be installed for tests.

Fixtures:

```text
valid_character_sprite_frames.tres
missing_death_sprite_frames.tres
renamed_attack_sprite_frames.tres
shortened_attack_sprite_frames.tres
```

## Required tests

### Creation

* creates all expected resources;
* creates one actor scene;
* assigns the selected `SpriteFrames`;
* creates expected nodes;
* attack hitbox starts disabled;
* definition can be loaded after creation.

### Manual preservation

1. Generate actor.
2. Move hitbox manually through test code.
3. Assign a sound.
4. Add an event.
5. Refresh metadata.
6. Verify all manual values remain unchanged.

### Animation rename

1. Contract points to `attack`.
2. Source changes to `attack_primary`.
3. Refresh metadata.
4. Verify mapping remains `attack`.
5. Verify validation reports a missing animation.
6. Verify suggested replacement is reported.

### Frame reduction

1. Event targets frame five.
2. Source animation shrinks to four frames.
3. Refresh metadata.
4. Verify event remains at frame five.
5. Verify validation error is produced.

### Runtime event dispatch

* sound event fires once;
* hitbox enable event enables correct hitbox;
* disable event disables it;
* replaying animation resets fired events;
* unrelated animation does not trigger event;
* disabled event does not fire.

### Preview

* actor instantiates;
* animation can be selected;
* frame label updates;
* event log receives events;
* no runtime errors are emitted.

---

# 21. Coding-Solo Godot MCP workflow

Codex should use the MCP for verification, not for designing the architecture.

Recommended loop:

```text
1. Inspect repository.
2. Confirm Godot version.
3. Confirm Aseprite Wizard installation and imported resource behavior.
4. Implement one vertical slice.
5. Launch Godot.
6. Enable plugin.
7. Capture parser/editor errors.
8. Fix all errors.
9. Generate a fixture actor.
10. Run preview.
11. Capture runtime output.
12. Run automated tests.
13. Review generated files.
14. Verify safe metadata refresh.
```

Codex must not claim success based only on code inspection.

It must provide evidence from:

* successful Godot launch;
* plugin enabled without errors;
* actor resource generation;
* generated scene loading;
* preview execution;
* validation execution;
* test results;
* captured debug output.

---

# 22. Implementation phases

## Phase 0 — Repository discovery

Codex must determine:

* Godot version;
* project directory;
* addon conventions;
* testing framework;
* Aseprite Wizard version and location;
* how imported `.aseprite` resources appear;
* existing actor architecture;
* collision layer conventions;
* audio bus conventions.

Output:

```text
docs/actor_pipeline/discovery.md
```

Do not change gameplay architecture during this phase.

---

## Phase 1 — Runtime vertical slice

Implement:

* `ActorDefinition`;
* `AnimationContract`;
* `AnimationEvent`;
* `AnimationEventSet`;
* `ActorSoundSet`;
* `ActorAnimator`;
* `ActorAnimationEventPlayer`;
* `HitboxController`;
* `ActorAudioController`;
* base actor template.

Manually create one fixture actor without editor generation.

Acceptance criteria:

* idle and attack can play;
* attack locks until finished;
* hitbox enables and disables on configured frames;
* sound event resolves correctly;
* all hitboxes are disabled after attack;
* no parser or runtime errors.

This phase proves the runtime model before building generation tooling.

---

## Phase 2 — Actor Factory

Implement:

* creation request;
* path policy;
* builders;
* actor dock;
* create-actor workflow;
* deterministic file generation;
* conflict checks.

Acceptance criteria:

* selecting `SpriteFrames` and entering an actor ID creates a usable actor;
* generated actor loads;
* runtime components are connected;
* resource files are external and editable;
* generation does not overwrite existing files.

---

## Phase 3 — Validation

Implement all essential validators.

Acceptance criteria:

* valid actor produces no errors;
* missing animation produces a specific error;
* invalid event frame produces a specific error;
* missing sound produces a specific error;
* missing hitbox produces a specific error;
* validation can run for one actor and all actors.

---

## Phase 4 — Metadata refresh

Implement non-destructive refresh.

Acceptance criteria:

* new animations are discovered;
* removed animations are reported;
* changed frame counts are recorded;
* manual events remain unchanged;
* manual sounds remain unchanged;
* hitboxes remain unchanged;
* scene is not regenerated.

---

## Phase 5 — Preview

Implement reusable preview scene.

Acceptance criteria:

* selected actor loads;
* all animations are selectable;
* frame stepping works;
* event log works;
* collision overlays can be toggled;
* sound events can play;
* preview produces no errors.

---

## Phase 6 — Inspector polish

Only after all previous phases pass:

* custom Inspector buttons;
* better event summaries;
* resource navigation;
* improved validation UI;
* shortcuts and context-menu actions.

This phase is optional for the MVP.

---

# 23. One-hour implementation target

The one-hour MVP should include only:

* core resources;
* one character template;
* runtime animation-event dispatch;
* hitbox enable/disable;
* sound playback;
* basic actor-generation dock;
* basic validator;
* one preview scene;
* one integration fixture.

Defer:

* Inspector plugins;
* inherited generated scenes;
* multiple production archetypes;
* visual event timeline;
* automatic sound suggestions;
* custom hitbox editor;
* batch generation;
* polished icons and styling;
* automatic previews in the editor dock.

If time becomes constrained, prioritize in this order:

```text
1. Runtime contracts
2. Safe editable resources
3. Actor scene generation
4. Hitbox and sound events
5. Validation
6. Preview
7. Editor polish
```

---

# 24. Definition of done

The MVP is complete only when:

* plugin enables without errors;
* an imported `SpriteFrames` resource can be selected;
* an actor scene and companion resources are generated;
* the scene opens successfully;
* animations play through semantic roles;
* locked animation behavior works;
* hitbox events work;
* sound events work;
* hitboxes can be moved manually;
* sound resources and event frames can be edited manually;
* metadata refresh does not overwrite manual changes;
* validator detects missing or invalid data;
* preview scene runs;
* automated tests pass;
* Godot debug output contains no unexpected errors;
* README explains installation and usage.

---

# 25. Codex rules

Codex must follow these rules:

1. Do not parse `.aseprite` files.
2. Do not edit `.aseprite` files.
3. Depend only on imported `SpriteFrames`.
4. Do not duplicate Aseprite Wizard functionality.
5. Do not generate custom actor scripts unnecessarily.
6. Do not overwrite existing files.
7. Do not automatically repair ambiguous animation mappings.
8. Do not automatically shift animation events.
9. Do not store manual hitbox transforms in generated metadata.
10. Do not couple gameplay logic directly to frame numbers.
11. Use semantic animation roles.
12. Use stable event, sound and hitbox IDs.
13. Keep resources editable through the normal Inspector.
14. Validate before and after generation.
15. Run Godot and tests before claiming completion.
16. Keep the MVP small.
17. Do not implement a custom timeline editor.
18. Document ownership for every generated field.
19. Prefer typed GDScript.
20. Treat warnings as defects unless explicitly accepted.

---

# 26. Initial Codex task

Implement Phases 0–2 as a vertical slice.

Start by inspecting the project and confirming:

* Godot version;
* Aseprite Wizard installation;
* imported `.aseprite` resource type;
* existing test framework;
* existing actor conventions;
* collision layers;
* audio bus names.

Then implement one complete character pipeline supporting:

```text
idle
walk
attack
hurt
death
```

Required events:

```text
hitbox_enable
hitbox_disable
play_sound
action_complete
```

Generate:

```text
actor scene
actor definition
animation contract
animation event set
sound set
generation manifest
```

Use a shared actor template.

Create a preview/test fixture and prove:

* animation playback;
* locking;
* hitbox activation;
* hitbox deactivation;
* sound dispatch;
* action completion;
* manual resource editing;
* non-destructive metadata refresh.

Run Godot through Coding-Solo MCP, capture all debug output, fix all parser and runtime errors, and provide a final implementation report containing:

* files created;
* architecture implemented;
* tests executed;
* observed results;
* known limitations;
* deferred features;
* manual verification instructions.

Do not proceed to custom Inspector editors or timeline tooling until the vertical slice passes.
