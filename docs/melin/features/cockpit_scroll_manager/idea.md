# Cockpit Scroll Manager — Idea

## Problem

The cockpit view needs convincing motion outside the car without building a full 3D world. Road stripes, traffic, and roadside scenery should travel from the horizon toward the player in a way that reads as forward driving.

## Desired experience

- The cockpit/interior stays in the foreground as a fixed frame.
- A horizon/vanishing area sits ahead of the player.
- Each scroll element begins small near that horizon and grows as it approaches the bottom of the window.
- Every element follows a perspective path rather than moving straight down the screen.
- Paths farther left or right lean farther toward their respective side.
- A shared curve bends those paths, creating a sense of driving over a curved world/road rather than across a flat screen.

## First model

Each element has a normalized depth `t`:

- `t = 0`: horizon / far distance.
- `t = 1`: near the cockpit / bottom of the window.

The manager converts `(lane_or_side_offset, t)` into screen position, scale, and ordering. Road stripes, cars, and trees use the same projection rules but have different spawn/recycle behavior and art.

The initial configuration exposes:

- `max_angle_left`
- `max_angle_right`
- `curve_factor`

At `t = 0`, all paths converge close to the horizon. At increasing `t`, the side offset determines a left/right perspective angle; `curve_factor` adds a shared nonlinear bend.

## Scope

### In

- Scroll-manager projection for road stripes, cars, and trees.
- Per-element movement along perspective/curved paths.
- Configurable left/right maximum angles and world/road curve factor.
- Depth scaling, draw order, spawn, and recycling suitable for a 2D cockpit game.

### Out for the first slice

- Physics collisions and traffic AI.
- A real 3D road mesh.
- Full cockpit/dashboard implementation.
- Art production.

## Open questions

- `curve_factor` is a constant configuration value for the visual world/road curvature. It is not driven by steering.
- Does traffic stay in discrete lanes while trees use continuous roadside bands?
- Where exactly is the horizon and playable cockpit-window rectangle in the final composition?
- Should the near camera movement be constant speed, or controlled by acceleration/braking?
