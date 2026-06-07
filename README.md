# Emberhold

A complete **Godot 4.6.3** co-op + PvP dungeon raid, exported to **mobile web**
(single-threaded HTML5, Compatibility / WebGL2) so it runs in your phone's default
browser — Safari on iOS, Chrome / Firefox on Android — and on desktop.

> Tap to start, pick a hero, raid a skeleton-haunted dungeon with friends or duel them.

## Play

- **Preview build:** deployed per-session to the Gogi preview host (see the PR / chat for the link).
- **Multiplayer:** the room code lives in the URL (`...?room=ABCDE`). Open the same link in a
  second tab or send it to a friend to share the world live. In-game, the **SHARE LINK** button
  copies your room URL to the clipboard.

### Controls
| Action | Touch | Keyboard / Mouse |
| --- | --- | --- |
| Move | Left-half joystick (drag anywhere on the left) | `WASD` / arrows |
| Look | Drag on the right half | Right-mouse drag |
| Light attack (combo) | `ATTACK` button | `J` or `Space` |
| Heavy / special attack | `SPECIAL` button | `L` |
| Swap weapon | `WEAPON` button (shows current) | `U` |
| Dodge roll | `DODGE` button | `K` or `Shift` |
| Wave / Cheer | `WAVE` / `CHEER` buttons | `E` / `Q` |
| Talk to an NPC | `TALK` button (appears nearby) | same |
| Mute | `SOUND` toggle (top-right) | same |

The HUD is fully **anchored** (safe-area-aware top-right cluster, big thumb-sized targets,
no overlap with the drag-look region — look is routed through `_unhandled_input` so every
button consumes its own tap), and every button has a press/scale + brightness-pop animation.

### Arsenal
Cycle weapons live with the **WEAPON** button (or `U`). Each has its own held KayKit models,
a light combo + a heavy attack, and a distinct feel; attacks **aim-snap to the nearest enemy in
range** so taps never whiff, and every landed hit throws sparks + a hit-flash + camera-shake.

| Weapon | Type | Feel |
| --- | --- | --- |
| **Axe + Shield** | 1H melee | balanced 3-hit slice/chop combo; heavy lunging stab |
| **Warhammer** | 2H melee | slow, huge damage, wide arc; heavy = a 360° spin that cleaves, big shake |
| **War Spear** | 2H melee | long reach, narrow thrust; heavy wide slice |
| **Longbow** | ranged | fast amber arrows; heavy = a heavier power shot |
| **Arcane** | ranged (spell) | homing-aimed magic bolts; heavy = a charged blast |

Heroes start with a fitting weapon (Knight → Axe, Rogue → Longbow, Mage → Arcane) but all five
are available to everyone.

## Features

- **Two areas in one shared world** — a torchlit **hub town** and a **dungeon** reached through a
  glowing descent portal. A lit `WorldEnvironment` (procedural sky, soft shadows, fog, ACES
  tonemapping) plus an inverted-hull **ink outline** on every hero & skeleton gives the committed
  KayKit chunky-adventure look. The environment darkens and the fog thickens as you descend.
- **Heroes & arsenal** — choose **Knight / Mage / Rogue** (KayKit). Third-person with a
  collision-aware `SpringArm3D` follow camera; idle/walk/run locomotion, attack, dodge, hit & death
  reactions; the hero always faces the way it moves. Five swappable weapons (axe+shield, warhammer,
  spear, longbow, arcane) attach real KayKit models to the rig's hand bones, each with its own
  light-combo + heavy attack, damage, reach, arc, cadence and screen-shake; ranged weapons fire a
  real traveling projectile that sparks on impact.
- **LLM NPCs** — a gruff **blacksmith (Doran)** and a nervous **quest-giver (Pip)** you can walk up
  to and *talk to*. They reply in character and remember the conversation (chat box + quick-reply
  chips + an animated thinking indicator), powered by the hosted `npc.myapping.com` brain.
- **PvE** — the dungeon is full of skeletons (three varied models, per-instance tint / scale /
  animation offset so the crowd never looks copy-pasted) that **patrol, chase, and attack**. Every
  landed hit shows a spark burst + a white flash + a short camera-shake; enemies and the player
  have health bars, with death & respawn.
- **PvP** — players in the same dungeon can also duel, with synced health and respawn.
- **Multiplayer** — built on **Supabase Realtime broadcast** (client-authoritative friends-play):
  name-tagged heroes, wave/emote, and synced positions / health / hits / equipped weapon. Dungeon
  skeletons are **host-elected** (the lowest peer id simulates them and broadcasts state; others
  render replicas; damage is routed to the host) so the co-op world stays consistent.
- **Audio** — light town music, a darker dungeon ambience, and SFX for footsteps, sword swing /
  hit, taking a hit, skeleton death, loot, UI taps and NPC replies — all procedurally synthesized,
  unlocked by the tap-to-start gesture (so iOS works), with a mute toggle.

## Architecture

| Path | Role |
| --- | --- |
| `main.gd` / `main.tscn` | Orchestrator: world + environment, HUD, tap-to-start + hero select, combat juice, multiplayer glue + host election, NPC chat |
| `scripts/world.gd` | Builds the hub town + dungeon (geometry, props, torches, portals, spawn data) |
| `scripts/player.gd` | Local hero controller (movement, follow camera, arsenal + light/heavy attacks, aim-snap, health, camera-shake) |
| `scripts/weapons.gd` | Arsenal data: per-weapon models, clips, damage, reach, arc, cadence, projectile |
| `scripts/projectile.gd` | Traveling bow arrow / magic bolt that scans for hits and emits `struck` |
| `scripts/remote_player.gd` | Networked peer avatar (interpolated, name tag, health bar, mirrored weapon + relayed attack clips) |
| `scripts/skeleton.gd` | Enemy AI (patrol/chase/attack) with host-authoritative / replica modes |
| `scripts/rig.gd` | KayKit rig helper: locomotion blend, one-shots, ink outline, weapon swap (attach/detach), tint, hit-flash |
| `scripts/npc.gd` | Talkable NPC (persona + capped conversation history) |
| `scripts/health_bar.gd` | Camera-facing 3D health bar |
| `scripts/audio.gd` | Music + pooled SFX + mute (autoload `Audio`) |
| `net.gd` | Supabase Realtime client (autoload `Net`) |
| `web/bridge.js` | JS bridge: Supabase Realtime broadcast transport + room helpers |

There are **no database tables** — multiplayer is transient pub/sub over Realtime broadcast and the
NPCs use a hosted endpoint, so nothing is persisted and no schema / RLS is required.

## Build it yourself

Requires **Godot 4.6.3** with the web export templates, plus `python3` + `numpy` + `ffmpeg` (to
regenerate audio).

```bash
./fetch_assets.sh          # download CC0 KayKit models + textures, synthesize audio (git-ignored)
# open the project in Godot 4.6.3 (it imports on first launch), or headless-export:
godot --headless --path . --import
godot --headless --path . --export-release "Web" out/index.html
cp web/bridge.js out/bridge.js   # so the relative <script src="bridge.js"> resolves
# serve out/ over http (it needs the correct .wasm MIME type)
```

The export preset is **single-threaded** (`thread_support=false`) and uses the **Compatibility**
renderer — required for mobile WebGL2 and for the preview host (which sets no COOP/COEP headers).

## Credits

Art: **KayKit** (Adventurers, Skeletons, props) and stylized seamless textures — all **CC0**.
Engine: **Godot 4.6.3**. Audio: procedurally synthesized (CC0). NPC dialogue: Claude Haiku via the
shared Gogi NPC endpoint.
