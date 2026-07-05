# Dream Runner Roadmap

## Current Status: MVP Release Candidate

The current `Game.tscn` build is a stable browser-first playtest candidate with the MVP shell, movement/glide, procedural world, dream-signal journey, prototype dimension layers, ambience, stylized character motion, giant landmarks, and Web export.

## Next Milestones

1. Playtest feedback pass: validate ten-minute movement, journey flow, readability, and friction.
2. Performance profiling pass: sustained chunk streaming, draw calls, memory, audio generation, and browser hitches.
3. Asset pipeline: define the workflow and create the first real custom player/environment assets.
4. Later polish: revisit character animation, sound design 02, mood/atmosphere, and revelation compositions.
5. Public browser build: cross-browser QA, itch.io preparation, packaging, and release notes.

## Known Not Final Yet

- Procedural character animation is suitable for the MVP, not final.
- Sound is a lightweight ambience foundation, not final sound design.
- Environment art remains improved primitive/in-engine geometry.
- Custom assets and the final asset pipeline come later.
- The MVP tests feel and flow, not final presentation.

## Sound / Ambience Pass 01

- Added browser-unlocked procedural wind, distant tonal ambience, mood coloration, and restrained dream-signal resonance.
- Sprinting and gliding gently strengthen the air layer; `M` toggles mute for testing.

## Dimension System Foundation Pass 01

- Reframed the five atmosphere moods as prototype dimension layers while preserving their visual and audio behavior.
- Added stable dimension IDs, conceptual display names, and a change signal for future layer-specific objects and story traces.

## Natural Launch Terrain Pass 01

- Added sparse world-space ridges, broad shelves, hill lips, and wind-carved rises for sprint-to-jump and glide flow.
- Terrain forms remain deterministic and share the visual/collision height sampler across chunk borders.
- Some dream-signal routes softly favor launch terrain; ordinary traversal remains the default.

## Dream Signal Path Variation Pass 01

- Dream destinations now follow a gently turning persistent journey heading.
- Controlled lateral and occasional wider arcs preserve long forward travel while avoiding straight-line repetition.
- Debug HUD reports placement mode and direction offset.

## Phase 0 — Setup

- [x] Install Git
- [x] Create local project folder
- [x] Initialize Git repository
- [x] Create first commit
- [x] Install Godot 4
- [ ] Install/Open VS Code
- [x] Connect project to GitHub
- [x] Set up Codex

## Phase 1 — Movement Prototype

Goal: make movement feel good before anything else.

- [x] Create Godot project
- [x] Create test level
- [x] Add placeholder player
- [x] Implement third-person movement
- [x] Implement high-speed running
- [x] Implement high jump
- [x] Implement smooth landing
- [x] Implement third-person camera
- [x] Add speed/jump debugging values
- [x] Complete Movement Laboratory tuning pass

### Current Build Status

The first playable movement prototype and Movement Laboratory are complete. The current build includes high-speed running, high jump, smooth air control, glide/float movement, a debug HUD, an expanded handcrafted test area, browser export, and Web-compatible mouse capture.

`Game.tscn` is now the main playable scene and launches when the project runs. It contains the procedural world setup promoted from the terrain prototype. `Main.tscn` remains available as the stable Movement Laboratory backup, and `ProceduralTest.tscn` remains available as the procedural terrain sandbox.

World Life Pass 01 adds lightweight drifting dream motes, subtle canopy and landmark motion, more organic prop variation and clusters, and softly glowing distant landmarks.

Dream Trail / Destination Pass 01 adds a soft exploration loop: follow a distant dream signal, reach it, and watch a new destination appear farther through the procedural world.

Dream Signal Guidance + Prop Scale Pass 01 adds a minimal off-screen signal indicator, a stronger long-distance beam, and broader seeded tree and rock size variation with rare giant silhouettes.

Atmosphere Mood States Pass 01 adds five faded sky, fog, lighting, and mote moods with gentle transitions and `F4` developer cycling.

Giant Forms / Revelation Landmarks Pass 01 adds rare deterministic giant trees, pale pillars, tilted monoliths, and horizon rings placed as distant ridge-scale silhouettes.

Distant Landmark Visibility Pass 01 keeps lightweight, non-colliding giant-form silhouettes active beyond the full terrain grid and tunes mood haze for long-distance readability.

Atmosphere Mood Tuning Pass 02 strengthens the emotional contrast between dawn, overcast, golden, night, and dust-haze states while preserving distant silhouettes.

Revelation Composition Pass 01 adds deterministic ridge, solitary-giant, horizon-call, and liminal-clearing signal placement templates with quiet passages between them.

Revelation Composition Flow Fix Pass 01 makes signals long-range and strongly forward-biased, adds anti-backtracking clearance, and makes quiet travel the default.

### Next Milestone

**Superseded:** Web atmosphere smoke testing is complete. Use the release-candidate milestones at the top of this file.

## Phase 2 — First Playable Scene

Goal: make one handcrafted area that feels satisfying.

- [x] Expand the movement test area
- [x] Add handcrafted ramps, platforms, and jump obstacles
- [x] Add readable placeholder colors
- [x] Add rolling terrain
- [x] Add placeholder trees
- [x] Add placeholder rocks
- [x] Complete Atmosphere Pass 01
- [x] Add procedural sky
- [x] Improve lighting and ambient light
- [x] Add distance fog
- [x] Tune movement and camera

## Phase 3 — Dream Movement Polish

- [x] Add air control
- [x] Add glide/floating mechanic
- [x] Add camera FOV change at high speed
- [ ] Add landing effects
- [x] Add wind sound foundation
- [ ] Add footstep sound

## Phase 4 — Procedural Terrain

- [x] Start Procedural Terrain Spike 01 in a separate test scene
- [ ] Validate chunk seams and Web performance
- [x] Generate terrain chunks
- [x] Spawn chunks around player
- [x] Remove distant chunks
- [x] Place trees procedurally
- [x] Place rocks procedurally
- [x] Add seeded generation

## Phase 5 — Browser Export

- [x] Export Godot project to HTML5/Web
- [x] Complete browser export smoke test
- [x] Fix Web mouse capture/pointer lock
- [ ] Test browser performance
- [ ] Test remaining browser input behavior
- [ ] Fix loading issues
- [ ] Deploy prototype

## Phase 6 — Public Prototype

- [x] Add minimal title/start overlay
- [ ] Add restart button
- [ ] Add settings
- [ ] Add music
- [ ] Add polish
- [ ] Publish to public URL
