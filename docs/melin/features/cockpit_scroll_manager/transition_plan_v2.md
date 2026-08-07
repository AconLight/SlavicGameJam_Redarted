# Scroll Manager V2 - Transition Plan

## Why V1 is being replaced

V1 mixed projection, movement, pooling, preview setup, art roles, and actor testing in one manager. Its `depth` value changed meaning during implementation, which made stripe spacing and horizon entry impossible to reason about. The preview also overrides script defaults, so Inspector behavior does not match the script.

## V2 decisions

- `road_distance` is the only movement coordinate. `0.0` is the horizon and `1.0` is the near boundary.
- `ScrollManager2D` transforms road distance into screen position, scale, rotation, and draw order. It does not spawn content.
- `far_to_near_distance_ratio` is explicitly visual only. It maps road distance through inverse-square perspective; it never changes physical stream spacing.
- `ScrollElement2D` represents one projected instance. Its projection mode is `Flat` or `Vertical`.
- `ScrollSpawnHandler` sits beside/under a manager and owns one spawn recipe: content scene, slot, frequency, prewarm policy, relative speed, and active-instance limit.
- A handler creates every element at `road_distance = 0.0` and immediately projects it. Its first rendered anchor is therefore the perspective point.
- Preview trees, cars, and Boss are configured by preview handlers, not hardcoded into runtime manager code.

## Migration tasks

### Task 1 - Clean projection and element model

Replace V1 manager/element state with `road_distance`, named visual perspective conversion, slots, and two projection modes. Verify a direct element at road distance zero projects exactly to `perspective_point`.

### Task 2 - Spawn handlers and deterministic stripe stream

Add `ScrollSpawnHandler`. It spawns an element at the perspective point on a configurable interval. Build a centre-slot stripe handler whose interval derives from desired road spacing and current world speed. Verify fixed source spacing and no lower-screen spawn.

### Task 3 - Generic content and preview composition

Move tree/car/Boss recipes into preview handlers. Use Boss at slot `2` with relative speed `-0.3`. Verify vertical content stays upright and all content is optional `PackedScene` data.

### Task 4 - Visual tuning and retirement

Tune the perspective exponent and path bend in the preview. Remove obsolete V1 fields and document the integration contract.

## Acceptance criteria

- Every newly spawned element has an anchor exactly at `perspective_point` on its first frame.
- Flat stripe instances retain equal `road_distance` spacing.
- Projection controls never alter spawn timing or physical spacing.
- Trees/cars/Boss are preview data, not special cases in the manager.
- `Flat` follows path rotation; `Vertical` remains upright.
