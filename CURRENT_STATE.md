# DreamRunner Current State

## Project summary

DreamRunner is a browser-first third-person dream-running game built in Godot 4 with GDScript. Its core experience is fast, calm traversal through a procedural dream landscape: run, jump, glide, follow dream signals, and keep exploring without combat, timers, scoring pressure, or hard failure states. The current build is the first MVP release candidate: a stable playtest build intended for approximately ten-minute sessions.

## Current main scene

- `res://scenes/Game.tscn` is the real main playable scene and the project F5 entry point.
- `res://scenes/Main.tscn` is retained as the old stable Movement Laboratory and backup.
- `res://scenes/ProceduralTest.tscn` is retained as the procedural terrain sandbox.

## Current gameplay systems

Dream signal placement is flow-first but no longer linear: a persistent journey heading turns gently between destinations, while controlled lateral arcs create long, recoverable left/right variations without backtracking.

- Third-person WASD movement with stable acceleration and deceleration.
- High-speed sprinting with speed-based camera FOV.
- High jump, air control, and glide/float while descending.
- Slope-aware movement with restrained uphill penalties and downhill boosts.
- Smooth camera orbit, pitch limits, spring-arm collision, and interpolation-aware follow.
- A stylized primitive runner silhouette with speed-synced procedural locomotion, airborne posing, and a height-blended glide pose.
- `R` reset/recenter to the starting area.
- A soft exploration loop: reach the active dream destination and a new signal appears farther ahead.
- No enemies, scoring, timer, fail state, or collectibles.

## Current world systems

- A first cohesive in-engine palette now unifies the symbolic runner, dusty terrain, muted vegetation and stone, restrained landmarks, and pale dream signal.
- Natural launch terrain uses sparse world-space ridge fields to form broad slopes, shelves, hill lips, and valley edges while keeping chunk meshes and collision seamless.
- A minority of dream-signal routes softly prefer launch-friendly terrain along their approach; normal traversal remains the default.
- Seeded procedural rolling terrain generated in streamed chunks around the player.
- Stable active chunk radius with distant chunk removal.
- Deterministic procedural trees, rocks, and surreal landmarks.
- Seeded prop rotation, color, clustering, and small-to-rare-giant scale variation.
- Rare revelation regions place solitary giant trees, pale stone pillars, tilted monoliths, or standing horizon rings on open ridge-like terrain.
- Lightweight, non-colliding far proxies keep rare giant silhouettes visible beyond the full terrain streaming radius.
- Spawn clearance and spacing rules preserve open sprint lanes near the starting area.
- Centralized gentle canopy sway and landmark pulsing.
- Lightweight dream atmosphere with 48 drifting/recycled motes rendered in one `MultiMesh`.
- Five prototype dimension layers smoothly control sky, fog, ambient light, directional light, and mote color/intensity.
- Dimension palettes preserve the existing dawn, overcast, golden, night, and dust-haze visual recipes while reframing them as layers of one reality.
- Very rare primitive human traces now appear as roadside shelters, dead utility poles with broken markers, and ruined frames. They reveal by dimension and remain non-colliding to preserve high-speed flow.
- One active primitive-based dream signal with terrain-aware placement, slope checks, glow, pulse, orb, rings, and a long-distance beam.
- Dream signals use episodic composition templates to favor ridge reveals, solitary giants, horizon calls, and open liminal clearings without adding props.
- Destination placement is flow-first: long-range signals favor the player’s travel heading, reject nearby/backtracking candidates, and use quiet forward passages most often.
- The signal brightens when the player travels far away; the player is not punished or forcibly redirected.

## Current UI/HUD systems

- Procedural ambience begins after the browser-safe entry click, responds subtly to dimension and movement, and can be muted with `M`.

- Start overlay: "Click to enter dream" plus movement controls.
- Clicking captures the mouse and unlocks audio; `Esc` releases the mouse and pauses; clicking the overlay resumes and recaptures it.
- Minimal normal-play hint: "Follow the dream signal".
- Off-screen signal arrow and distance label, hidden when the signal is visible or the mouse is released.
- Debug HUD toggled with `F3`; hidden by default for a cleaner presentation.
- `F4` cycles Waking / Pale World, Dead / Empty World, Memory / Golden World, Liminal Night / Dream-Between, and Forgotten Road / Dust World for development testing.
- Debug information includes movement state, speed, vertical velocity, sprint/glide state, mouse status, current chunk, active chunks, active props, giant forms, far silhouettes, dream motes, current dimension, destination distance, composition type, and placement mode.

## Current browser/export status

- Browser/Web is the primary target.
- The project uses Godot 4.7, GL Compatibility rendering, and Jolt Physics.
- Pointer-lock behavior is designed around browser user-gesture requirements.
- The existing `Web` export preset outputs to `res://exports/web/DreamRunner.html`.
- Web exports and browser smoke tests have succeeded; the current export is playable as an MVP release candidate.
- Continue checking sustained chunk-streaming performance, loading hitches, browser input behavior, and unusual aspect ratios.

## Important files and what they do

- `res://project.godot` - main scene, input actions, renderer, physics, and project settings.
- `res://scenes/Game.tscn` - production playable scene and integration point for all current systems.
- `res://scenes/Main.tscn` - preserved Movement Laboratory backup.
- `res://scenes/ProceduralTest.tscn` - preserved procedural sandbox.
- `res://scripts/player_controller.gd` - movement, sprint, jump, glide, slopes, camera, pointer lock, and reset.
- `res://scripts/terrain_chunk_manager.gd` - terrain generation, chunk streaming, props, collisions, shared materials, and environmental motion.
- `res://scripts/dream_atmosphere.gd` - batched drifting dream motes and interpolated prototype dimension layers.
- `res://scripts/dream_destination_manager.gd` - active destination placement, visual marker, trigger response, regeneration, and lost-player brightness.
- `res://scripts/dream_signal_guidance.gd` - off-screen direction arrow and signal distance.
- `res://scripts/debug_hud.gd` - `F3` diagnostics and runtime counters.
- `res://scripts/start_overlay.gd` - start/control overlay visibility based on mouse capture.
- `res://scripts/audio_manager.gd` - browser-unlocked procedural ambience, dimension coloration, signal resonance, and `M` mute.
- `res://export_presets.cfg` - Web export configuration.
- `res://GAME_DESIGN.md` - high-level fantasy and design principles; some build-status text is outdated.
- `res://ROADMAP.md` - milestone history and future work; several procedural checklist items lag behind implementation.
- `res://AGENTS.md` - Codex development priorities and constraints; its build-status section is outdated.

## Things that must not be broken

- Stable movement feel, sprint speed, high jump, glide, air control, and slope behavior.
- Smooth camera follow, pitch limits, spring arm, FOV response, and jitter fixes.
- Browser click-to-capture, `Esc` release, and click-to-recapture behavior.
- `R` reset, start overlay, off-screen guidance, `F3` debug toggle, and `F4` dimension cycling.
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

## Known Not Final Yet

- Procedural character animation is acceptable for MVP playtesting, but it is not the final animation solution.
- Sound is an ambience foundation, not final sound design or music.
- Environment silhouettes are improved but still use primitive, in-engine geometry.
- A real custom-asset pipeline and final asset direction come later.
- This MVP validates movement, atmosphere, journey flow, and browser performance—not final presentation quality.

## Next likely milestones

- Run a structured playtest-feedback pass before changing the core feel.
- Profile sustained chunk streaming, draw calls, procedural audio, and memory in Web builds.
- Establish the asset pipeline and create the first real custom environment/player assets.
- Revisit character animation after playtest and asset-pipeline decisions.
- Later passes: sound design 02, mood/atmosphere polish, and revelation-composition polish.
- Prepare and publish a public browser build, including itch.io packaging and cross-browser checks.
