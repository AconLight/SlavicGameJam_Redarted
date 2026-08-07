# Melin Tooling Rules

Use the smallest reliable toolset that can answer the current question. Tool availability must be checked rather than assumed.

## Before feature work

1. Confirm the active Godot project path and avoid editing a similarly named copy.
2. Inspect the relevant scene/resource/script and the current Git state before changing anything.
3. Identify whether the work needs an editor preview, a headless parser check, a focused test, or all three.

## Godot

- Use the configured Godot console executable for repeatable parser checks and focused headless tests.
- Use the editor/scene preview for visual, input, animation, and lighting behavior.
- Treat generated/imported files carefully: verify that a fresh clone does not require artist-only tooling to load gameplay scenes.
- Record any required external executable (such as Aseprite or Laigter) and provide a graceful failure path when it is absent.

## Godot MCP

- Use Godot MCP only when its server is installed and connected for this project.
- Start with one small read-only call to verify the connection and active project before relying on it.
- Test one MCP implementation at a time; do not mix results from different servers in the same verification step.
- MCP augments normal Godot checks; it does not replace opening/running the affected scene.

## Graphify

- For codebase architecture, ownership, or relationship questions, first check for an existing `graphify-out/graph.json` and query it when present.
- If no usable graph exists, build or update one only when its value outweighs the setup cost.
- If Graphify cannot index a relevant format (for example GDScript), record that limitation and use focused source inspection instead.

## Context mode

- Use context-mode tools for large logs, build output, broad searches, test output, and data that would otherwise flood the working context.
- Use normal shell commands for short, predictable observations.
- Keep file edits in explicit patches; context-mode is for analysis and summarization, not silent source mutation.

## Shell, Git, and external tools

- Prefer `rg` for source searches.
- Use `apply_patch` for deliberate source and documentation edits.
- Never reset, discard, or overwrite unrelated user changes.
- Before invoking an external tool, verify its path or provide a clear configuration error.
