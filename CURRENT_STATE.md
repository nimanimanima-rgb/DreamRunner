# DreamRunner Current State

## Project summary

DreamRunner is a browser-first third-person dream-running game built in Godot 4.7 with GDScript. Its core experience is fast, calm traversal through a procedural dream landscape: run, jump, glide, follow dream signals, and keep exploring without combat, timers, scoring pressure, or hard failure states. The current `Game.tscn` build is an MVP release candidate intended for approximately ten-minute playtest sessions.

## Current main scene

- `res://scenes/Game.tscn` is the real main playable scene and the project F5 entry point.
- `res://scenes/Main.tscn` is retained as the old stable Movement Laboratory and backup.
- `res://scenes/ProceduralTest.tscn` is retained as the procedural terrain sandbox.

## Current gameplay systems

Dream signal placement is flow-first but no longer linear: a persistent journey heading turns gently between destinations, while controlled lateral arcs create long, recoverable left/right variations without backtracking.

- Third-person WASD movement with stable acceleration and deceleration.
- High-speed running at the former 34 m/s sprint pace, with no modifier key required and speed-based camera FOV.
- High jump, air control, and glide/float while descending.
- Slope-aware movement with restrained uphill penalties and downhill boosts.
- Smooth camera orbit, pitch limits, spring-arm collision, and interpolation-aware follow.
- A stylized primitive runner silhouette with speed-synced procedural locomotion, airborne posing, and a height-blended glide pose.
- `R` reset/recenter to the starting area.
- A soft exploration loop: reach the active dream destination and a new signal appears farther ahead.
- No enemies, scoring, timer, fail state, or collectibles.

## Current world systems

- The first Dream Highlands biome identity now unifies dusty olive grass, exposed earth, pale stone, cool fog valleys, wind-shaped vegetation, weathered human traces, restrained landmarks, and the pale dream signal.
- Terrain uses browser-safe vertex color to blend muted grass, earth, stone, and cooler lowland tones without textures or custom shaders; the old alternating chunk-color look is gone.
- Each streamed chunk carries one slope-filtered `MultiMesh` of 48 wind-leaning grass clumps, adding ground-scale richness without physics or per-blade nodes.
- The Extreme Dramatic Terrain experiment pushes rolling relief to 26 m, horizon-scale signed highland masses to 24 m with 1.45x deeper valleys, and broad launch shelves to 28 m. A ±1.2 km probe spans roughly 97 vertical metres, creating taller ridge silhouettes, deeper basins, and substantially longer glide lines while retaining one seamless world-space height function for visuals and collision.
- These extreme terrain values are deliberately exposed and labeled as experimental tuning, not final biome balance; destination slope safeguards and flat-ground prop filters remain active.
- Extreme terrain remains intact inside a three-layer far-world system. The inner 25 chunks are playable at 20x20 resolution; a 56-chunk, half-resolution mid ring extends terrain-only coverage to roughly 720 m per axis; two tiny radial meshes continue sampled highlands and irregular horizon ridges from 700 m to 2.3 km. Mid/far layers have no collision, grass, props, lamps, or traces.
- The camera far clip is 3 km. Slightly lighter dimension-specific fog and muted dimension-tinted far materials create atmospheric depth instead of a hard terrain cutoff; cheap giant-landmark proxies now reach across an 11-chunk radius.
- Regular trees now require a flatter center normal plus four-point base-footing validation and receive a subtle 0.2 m visual embed. Wide passive trace foundations use a similar multi-point check; lamp posts retain their existing open-ground slope filter.
- A minority of dream-signal routes softly prefer launch-friendly terrain along their approach; normal traversal remains the default.
- Destination placement now checks both local and broader slope variation, makes additional terrain-aware attempts, and searches nearby safe ground before accepting a direct fallback.
- Seeded procedural rolling terrain generated in streamed chunks around the player.
- Stable near/mid LOD radii with distant chunk removal, automatic detail-ring promotion, and chunk-snapped far-world recentering.
- Deterministic wind-bent highland trees, embedded weathered rocks, and restrained surreal landmarks share one desaturated material language.
- Seeded prop rotation, color, clustering, and small-to-rare-giant scale variation.
- Rare revelation regions place solitary giant trees, pale stone pillars, tilted monoliths, or standing horizon rings on open ridge-like terrain.
- Lightweight, non-colliding far proxies keep rare giant silhouettes visible beyond the full terrain streaming radius.
- Scale variation, giant landmarks, and far silhouettes improve environmental readability while preserving open traversal space.
- Giant trees now use asymmetric windswept crowns; pillars and monoliths have quieter broken silhouettes; horizon rings retain their distant double-ring echo. All far proxies reuse cached dimension palettes: subdued in Waking, warm in Memory, weathered in Dust, drained in Dead/Empty, and cool-emissive in Liminal Night.
- Spawn clearance and spacing rules preserve open running lanes near the starting area.
- Centralized gentle canopy sway and landmark pulsing.
- Lightweight dream atmosphere uses 64 varied drifting/recycled motes in one `MultiMesh` plus ten slow, player-following cloud forms in a second `MultiMesh`; neither system uses real lights or volumetrics.
- Five prototype dimension layers smoothly control sky, fog, ambient light, directional light, and mote color/intensity.
- Dimension palettes preserve the existing dawn, overcast, golden, night, and dust-haze visual recipes while reframing them as layers of one reality.
- Very rare primitive human traces now use clearer travel-worn silhouettes: platform shelters with benches and route signs, dead utility poles with broken line hardware and markers, and stripped roadside frames with partial walls. Dimension changes apply cached visibility and material profiles: ordinary in Waking, warm shelters in Memory, dusty poles in Forgotten Road, cold ruins in Dead/Empty, and faint silhouettes in Liminal Night. They remain non-colliding to preserve high-speed flow.
- Passive traces use their rare 5% per-chunk chance for normal play; an exported multiplier remains available for focused testing.
- Reusable non-colliding roadside lamp posts use a 68% eligible-chunk chance, a multi-candidate open-ground search, and one guaranteed forward-area introduction lamp. Their taller silhouettes, larger bulbs, and wider emissive ground pools remain light-node-free; dimension profiles range from readable-but-drained Dead lamps to warm Memory and sacred Liminal lamps.
- One active primitive-based dream signal with terrain-aware placement, slope checks, glow, pulse, orb, rings, and a long-distance beam.
- The first signal uses a restrained onboarding profile: 380–460 m away, close to the opening view, launch-route favored, and slightly clearer until reached. Later destinations retain the full varied journey rules.
- The dream signal responds to dimensions with restrained color, opacity, glow, pulse, and procedural resonance profiles while preserving long-distance readability.
- Dream signals use episodic composition templates to favor ridge reveals, solitary giants, horizon calls, and open liminal clearings without adding props.
- Destination placement is flow-first: long-range signals favor the player’s travel heading, reject nearby/backtracking candidates, and use quiet forward passages most often.
- The signal brightens when the player travels far away; the player is not punished or forcibly redirected.

## Current UI/HUD systems

- Procedural ambience is explicitly unlocked/retried from the browser-safe entry or resume click, responds subtly to dimension and movement, and can be muted with `M`.
- Sound Design Pass 02 raises the shared mix by `+3 dB` (about 41% linear gain), gives signal resonance one additional dB of clarity, and differentiates dimensions through smoothly blended wind, air pressure, drone weight, and pitch.

- Start overlay: "Click to enter dream," a quiet signal-following prompt, and essential movement, mouse, dimension, pause, reset, and mute controls. Developer-only F3 help stays off the player-facing overlay.
- Clicking explicitly unlocks audio before pointer capture; `Esc` releases the mouse and pauses; clicking the overlay retries audio, resumes, and recaptures it.
- Minimal normal-play hint: "Follow the dream signal".
- Off-screen signal arrow and distance label, hidden when the signal is visible or the mouse is released.
- Debug HUD toggled with `F3`; hidden by default for a cleaner presentation.
- `Q` shifts through Waking / Pale World, Dead / Empty World, Memory / Golden World, Liminal Night / Dream-Between, and Forgotten Road / Dust World.
- Dimension changes use a brief 0.7-second color veil and quiet procedural tone while the existing atmosphere continues its smooth interpolation; player control is never blocked.
- Readability tuning settles atmosphere changes over 6 seconds and protects signal, trace, and landmark contrast in the darker dimensions without increasing visual density.
- Debug information includes FPS, movement state, speed, vertical velocity, glide state, mouse status, current chunk, visible/detailed chunk counts, active props, giant forms, far silhouettes, dream motes, current dimension, destination distance, composition type, and placement mode. Audio dimension targets update only when the active layer changes rather than being rediscovered every frame.

## Current browser/export status

- Browser/Web is the primary target.
- The project uses Godot 4.7, GL Compatibility rendering, and Jolt Physics.
- Pointer-lock behavior is designed around browser user-gesture requirements.
- The `Web` release preset outputs to `res://exports/web/index.html`; deploy from `exports/web` with `vercel.cmd --prod` so Vercel serves it at the site root.
- The Web package includes `Game.tscn` and its resolved dependencies rather than the preserved legacy test scenes.
- `exports/.gdignore` prevents generated Web files from entering Godot's import scan. Minimal Vercel headers keep `index.html` revalidated while allowing the CDN to cache the larger engine/data files between requests.
- Web exports and browser smoke tests have succeeded; the current export is playable as an MVP release candidate.
- Continue checking sustained chunk-streaming performance, loading hitches, browser input behavior, and unusual aspect ratios.

## Important files and what they do

- `res://project.godot` - main scene, input actions, renderer, physics, and project settings.
- `res://scenes/Game.tscn` - production playable scene and integration point for all current systems.
- `res://scenes/Main.tscn` - preserved Movement Laboratory backup.
- `res://scenes/ProceduralTest.tscn` - preserved procedural sandbox.
- `res://scripts/player_controller.gd` - high-speed movement, jump, glide, slopes, camera, pointer lock, and reset.
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

- Stable 34 m/s running feel, high jump, glide, air control, and slope behavior.
- Smooth camera follow, pitch limits, spring arm, FOV response, and jitter fixes.
- Browser click-to-capture, `Esc` release, and click-to-recapture behavior.
- `R` reset, start overlay, off-screen guidance, `F3` debug toggle, and `Q` dimension shifting.
- Procedural terrain seams, collision orientation, deterministic generation, and chunk recycling.
- Open running lanes and safe starting-area clearance.
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
- Passive storytelling traces are intentionally rare; do not raise their normal frequency without an explicit testing or tuning goal.
- Dimension layers, transitions, trace visibility, and signal profiles are foundation-level work, not complete parallel worlds.
- Sound is an ambience foundation, not final sound design or music.
- Environment silhouettes are improved but still use primitive, in-engine geometry.
- Preserve the current movement feel unless a task explicitly calls for movement tuning.
- A real custom-asset pipeline and final asset direction come later.
- This MVP validates movement, atmosphere, journey flow, and browser performance—not final presentation quality.

## Next likely milestones

- Run a structured playtest-feedback pass before changing the core feel.
- Tune dimension readability without turning layers into constant spectacle.
- Build Sound Design Pass 02 while preserving silence and browser-safe audio.
- Expand passive storytelling carefully, followed by small landmark-transformation prototypes.
- Profile sustained chunk streaming, draw calls, procedural audio, and memory in Web builds.
- Establish the first real custom environment/player asset pipeline.
- Prepare and publish a public browser build, including itch.io packaging and cross-browser checks.
