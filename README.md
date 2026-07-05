# Dream Runner

Dream Runner is a browser-based third-person movement game inspired by the peaceful endless driving experience of Slow Roads.

Instead of driving, the player runs, jumps, glides, and explores an endless dreamlike natural world.

## Core Fantasy

Run impossibly fast. Jump impossibly high. Move through a calm, endless landscape with no pressure, no enemies, and no hard failure state.

## Target Platform

Browser first.

## Engine

Godot 4.7 with the GL Compatibility renderer.

## Current Goal

Playtest and profile the first browser MVP release candidate before expanding scope.

## Current Build Status

The current browser-first MVP candidate includes:

- Fast third-person running, jumping, gliding, and procedural character motion
- Streamed procedural terrain with natural launch forms and giant landmarks
- Dream-signal journey loop with path variation and off-screen guidance
- Five dimension layers with atmospheric transitions, dimension-aware signals, and rare dimension-aware human traces
- Procedural ambience, stylized player silhouette/animation, improved environment silhouettes, and distant giant landmarks
- Start/pause shell, mouse capture, debug controls, reset, and Web export

## Next Milestone

**Playtest and Dimension Readability:** gather ten-minute-session feedback, tune layer readability, then continue sound, storytelling, profiling, and custom-asset work.

## Web deployment

Export the `Web` preset as a release build to `exports/web/index.html`. From `exports/web`, run `vercel.cmd --prod`; Vercel serves that directory at the deployment root. Keep the generated `.wasm`, `.pck`, `.js`, worklet, icon, and `index.html` files together.
