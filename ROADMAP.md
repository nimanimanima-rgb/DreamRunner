# Dream Runner Roadmap

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

### Next Milestone

**Web Atmosphere Smoke Test:** verify the larger scene, procedural sky, fog, lighting, and shadows in the browser before adding more world detail.

## Phase 2 — First Playable Scene

Goal: make one handcrafted area that feels satisfying.

- [x] Expand the movement test area
- [x] Add handcrafted ramps, platforms, and jump obstacles
- [x] Add readable placeholder colors
- [ ] Add rolling terrain
- [ ] Add placeholder trees
- [ ] Add placeholder rocks
- [x] Complete Atmosphere Pass 01
- [x] Add procedural sky
- [x] Improve lighting and ambient light
- [x] Add distance fog
- [ ] Tune movement and camera

## Phase 3 — Dream Movement Polish

- [x] Add air control
- [x] Add glide/floating mechanic
- [x] Add camera FOV change at high speed
- [ ] Add landing effects
- [ ] Add wind sound
- [ ] Add footstep sound

## Phase 4 — Procedural Terrain

- [x] Start Procedural Terrain Spike 01 in a separate test scene
- [ ] Validate chunk seams and Web performance
- [ ] Generate terrain chunks
- [ ] Spawn chunks around player
- [ ] Remove distant chunks
- [ ] Place trees procedurally
- [ ] Place rocks procedurally
- [ ] Add seeded generation

## Phase 5 — Browser Export

- [x] Export Godot project to HTML5/Web
- [x] Complete browser export smoke test
- [x] Fix Web mouse capture/pointer lock
- [ ] Test browser performance
- [ ] Test remaining browser input behavior
- [ ] Fix loading issues
- [ ] Deploy prototype

## Phase 6 — Public Prototype

- [ ] Add title screen
- [ ] Add restart button
- [ ] Add settings
- [ ] Add music
- [ ] Add polish
- [ ] Publish to public URL
