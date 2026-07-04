# DreamRunner Current State

## Project summary

DreamRunner is a browser-first third-person dream-running game built in Godot 4 with GDScript. Its core experience is fast, calm traversal through a procedural dream landscape: run, jump, glide, follow dream signals, and keep exploring without combat, timers, scoring pressure, or hard failure states.

## Current main scene

- `res://scenes/Game.tscn` is the real main playable scene and the project F5 entry point.
- `res://scenes/Main.tscn` is retained as the old stable Movement Laboratory and backup.
- `res://scenes/ProceduralTest.tscn` is retained as the procedural terrain sandbox.

## Current gameplay systems

- Third-person WASD movement with stable acceleration and deceleration.
- High-speed sprinting with speed-based camera FOV.
- High jump, air control, and glide/float while descending.
- Slope-aware movement with restrained uphill penalties and downhill boosts.
- Smooth camera orbit, pitch limits, spring-arm collision, and interpolation-aware follow.
- `R` reset/recenter to the starting area.
- A soft exploration loop: reach the active dream destination and a new signal appears farther ahead.
- No enemies, scoring, timer, fail state, or collectibles.

## Current world systems

- Seeded procedural rolling terrain generated in streamed chunks around the player.
- Stable active chunk radius with distant chunk removal.
- Deterministic procedural trees, rocks, and surreal landmarks.
- Seeded prop rotation, color, clustering, and small-to-rare-giant scale variation.
- Rare revelation regions place solitary giant trees, pale stone pillars, tilted monoliths, or standing horizon rings on open ridge-like terrain.
- Spawn clearance and spacing rules preserve open sprint lanes near the starting area.
- Centralized gentle canopy sway and landmark pulsing.
- Lightweight dream atmosphere with 48 drifting/recycled motes rendered in one `MultiMesh`.
- Five environmental mood states smoothly control sky, fog, ambient light, directional light, and mote color/intensity.
- One active primitive-based dream signal with terrain-aware placement, slope checks, glow, pulse, orb, rings, and a long-distance beam.
- The signal brightens when the player travels far away; the player is not punished or forcibly redirected.

## Current UI/HUD systems

- Start overlay: "Click to enter dream" plus movement controls.
- Clicking captures the mouse; `Esc` releases it; clicking again recaptures it.
- Minimal normal-play hint: "Follow the dream signal".
- Off-screen signal arrow and distance label, hidden when the signal is visible or the mouse is released.
- Debug HUD toggled with `F3`; hidden by default for a cleaner presentation.
- `F4` cycles Pale Dawn, Cold Overcast, Golden Dissolve, Blue Liminal Night, and Dust Haze Afternoon for development testing.
- Debug information includes movement state, speed, vertical velocity, sprint/glide state, mouse status, current chunk, active chunks, active props, giant forms, dream motes, current mood, and destination distance.

## Current browser/export status

- Browser/Web is the primary target.
- The project uses Godot 4.7, GL Compatibility rendering, and Jolt Physics.
- Pointer-lock behavior is designed around browser user-gesture requirements.
- The existing `Web` export preset outputs to `res://exports/web/DreamRunner.html`.
- Web debug exports and browser smoke tests have succeeded.
- Continue checking sustained chunk-streaming performance, loading hitches, browser input behavior, and unusual aspect ratios.

## Important files and what they do

- `res://project.godot` - main scene, input actions, renderer, physics, and project settings.
- `res://scenes/Game.tscn` - production playable scene and integration point for all current systems.
- `res://scenes/Main.tscn` - preserved Movement Laboratory backup.
- `res://scenes/ProceduralTest.tscn` - preserved procedural sandbox.
- `res://scripts/player_controller.gd` - movement, sprint, jump, glide, slopes, camera, pointer lock, and reset.
- `res://scripts/terrain_chunk_manager.gd` - terrain generation, chunk streaming, props, collisions, shared materials, and environmental motion.
- `res://scripts/dream_atmosphere.gd` - batched drifting dream motes and interpolated environmental mood states.
- `res://scripts/dream_destination_manager.gd` - active destination placement, visual marker, trigger response, regeneration, and lost-player brightness.
- `res://scripts/dream_signal_guidance.gd` - off-screen direction arrow and signal distance.
- `res://scripts/debug_hud.gd` - `F3` diagnostics and runtime counters.
- `res://scripts/start_overlay.gd` - start/control overlay visibility based on mouse capture.
- `res://export_presets.cfg` - Web export configuration.
- `res://GAME_DESIGN.md` - high-level fantasy and design principles; some build-status text is outdated.
- `res://ROADMAP.md` - milestone history and future work; several procedural checklist items lag behind implementation.
- `res://AGENTS.md` - Codex development priorities and constraints; its build-status section is outdated.

## Things that must not be broken

- Stable movement feel, sprint speed, high jump, glide, air control, and slope behavior.
- Smooth camera follow, pitch limits, spring arm, FOV response, and jitter fixes.
- Browser click-to-capture, `Esc` release, and click-to-recapture behavior.
- `R` reset, start overlay, off-screen guidance, `F3` debug toggle, and `F4` mood cycling.
- Procedural terrain seams, collision orientation, deterministic generation, and chunk recycling.
- Open sprint lanes and safe starting-area clearance.
- Dream destination placement, triggering, regeneration, and guidance.
- Batched mote rendering and browser-conscious performance.
- `Game.tscn` as the project main scene; preserve both legacy scenes.
- Web export compatibility and simple Godot-native structure.

## Known design direction

- Prioritize movement feel, calm exploration, atmosphere, freedom, and readable silhouettes.
- Keep the game dreamlike rather than arcade-heavy.
- Avoid enemies, combat, stressful timers, complex scoring, and punishing failure loops.
- Prefer small incremental changes, placeholder primitives, simple native Godot solutions, and browser-safe performance.
- Add visual life and direction without cluttering the world or UI.

## Next likely milestones

- Profile sustained chunk streaming and synchronous terrain/collision generation in Web builds.
- Validate chunk seams, large-prop collisions, open lanes, and memory behavior over long runs.
- Test pointer lock, keyboard input, signal guidance, and UI placement across browsers and aspect ratios.
- Tune fog, signal visibility, dream motes, giant prop frequency, and destination placement through playtesting.
- Add restrained movement polish such as landing feedback, wind audio, and footsteps.
- Reconcile outdated status text and roadmap checkboxes with the implemented build.
- Later: title/settings flow, music, deployment, and public prototype polish.
