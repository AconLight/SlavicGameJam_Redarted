# Cockpit Scroll Manager - V2 Implementation

## Runtime split

`ScrollManager2D` owns only projection:

- maps integer slots to lateral offsets;
- maps physical `road_distance` to visual path progress through `far_to_near_distance_ratio`;
- returns position, scale, rotation, and draw order.

`ScrollElement2D` owns one projected instance:

- `road_distance` is its physical position from horizon (`0.0`) to near boundary (`1.0`);
- `Flat` rotates with its path; `Vertical` remains upright;
- optional `content_scene` hosts any actor or packed scene.

`ScrollSpawnHandler` owns one spawn recipe:

- scene/debug content, projection mode, slots, scale, and relative speed;
- spawn interval or road-spacing-derived interval;
- active count and optional prewarmed instances.

Handlers are children of a manager. They create every new element at road distance zero and immediately apply projection, so its anchor starts exactly at `perspective_point`.

## Stripe stream

The stripe handler uses `derive_interval_from_road_spacing`.

`spawn interval = road spacing / world scroll speed`

This keeps the source road distance between stripe spawns stable even when tuning the global speed. Perspective never changes physical spacing: it only converts road distance into rendered progress.

## Preview recipes

The preview scene owns four independent handlers:

- centre-slot flat stripes;
- vertical roadside trees on slots `-4`, `-3`, `3`, and `4`;
- vertical cars on road slots;
- Boss actor at slot `2`, with relative speed `-0.3`.

Boss uses the full actor scene only as a generic-content demonstration. It remains visually idle until the source actor has a walk animation and an optional animation adapter is added.

## Tuning

- Put `perspective_point` on the cockpit artwork's horizon.
- Set `slot_lateral_spacing` for lane/roadside separation.
- Tune `far_to_near_distance_ratio` for physical perspective. `1` is nearly linear; `8` makes near apparent screen speed 64 times the horizon speed because screen motion follows inverse-square distance. This is a visual mapping, not a movement speed.
- Change a handler's `road_spacing` to alter stripe frequency.

## Verification

1. Godot 4.7.1 headless editor scan parses all V2 scripts and the preview scene.
2. Focused headless check confirms flat and vertical elements at road distance zero both project exactly to the perspective point.
3. Run `scenes/demo/cockpit_scroll_manager_preview.tscn` with F6 for visual tuning.
