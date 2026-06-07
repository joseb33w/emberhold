# Emberhold — build plan

A complete **Godot 4.6.3** co-op + PvP dungeon raid, exported to **mobile web**
(nothreads HTML5, Compatibility / WebGL2) so it runs in Safari (iOS) and Chrome (Android).

## Goal
- Real Godot project (NOT three.js/Phaser): tap-to-start, on-screen touch controls + WASD/mouse, fills the screen.
- KayKit chunky-adventure art with a committed direction: lit `WorldEnvironment` (sky, soft shadows, light fog, ACES) + inverted-hull ink outline on heroes & skeletons.
- Two areas in one shared world: a torchlit **HUB TOWN** and a **DUNGEON** reached through a descent portal.
- Third-person hero (Knight / Mage / Rogue) with a `SpringArm3D` follow camera; idle/walk/run blended by speed, attack, hit & death reactions; character faces its movement.
- Audio (unlocked by tap-to-start so iOS works): town music + dungeon ambience + SFX (footstep, sword swing, sword hit, take-hit, skeleton death, loot, UI tap, NPC blip) + mute toggle. Procedurally synthesized OGG, kept tiny.
- LLM NPCs (blacksmith + nervous quest-giver) via `npc.myapping.com/chat` — in-character, remembers the conversation, chat box + animated thinking indicator.
- PvE: skeletons (3 varied models + per-instance tint/scale) that patrol / chase / attack, with visible hit feedback (spark + flash + screen-shake), enemy + player health bars, death & respawn.
- PvP: players in the same dungeon can duel — synced health + respawn.
- Multiplayer over **Supabase Realtime broadcast**: shared world, name-tagged heroes, wave/emote, synced position/health/hits. Room code in the URL to share / open a second tab.

## Files to touch
- `project.godot`, `export_presets.cfg` — Compatibility renderer, nothreads Web preset, mobile head_include (viewport, Supabase CDN + `bridge.js`), `Net` + `Audio` autoloads.
- `web/bridge.js` — Supabase Realtime broadcast bridge (URL + anon key filled), name + room helpers.
- `net.gd` — Realtime client autoload.
- `scripts/rig.gd` — KayKit character rig helper (locomotion blend, one-shots, ink outline, weapon/shield attach).
- `scripts/player.gd`, `scripts/remote_player.gd`, `scripts/skeleton.gd`, `scripts/health_bar.gd`, `scripts/npc.gd`, `scripts/world.gd`, `scripts/audio.gd`.
- `main.gd`, `main.tscn` — orchestrator: world, HUD (joystick / look / attack / dodge / emote / mute / chat / room code), tap-to-start, camera-shake juice, multiplayer glue + host election.
- `tools/gen_audio.py`, `fetch_assets.sh` — regenerate audio / re-download CC0 models (binaries are git-ignored; the deployed preview bakes them in).
- `README.md`, `.gitignore`.

## Backend
- No DB tables. Multiplayer uses Supabase **Realtime broadcast** (transient pub/sub, anon key, public channel — client-authoritative friends-play); NPCs use the hosted `npc.myapping.com` brain. Nothing is persisted, so no schema / RLS is required.

## Verification approach
- Headless export to web (nothreads) + the vetted Godot smoke verifier (engine boots, canvas, clean console, screenshots) and visual critique of frames.
- Targeted checks: drive movement and confirm the hero faces travel direction (no `+Z` moonwalk); trigger an attack and assert spark/flash juice; multiplayer connect-path flag + headless packet injection (remote spawn, hit→hp drop, host-replica enemies) + a 2-client Node Realtime transport test; NPC endpoint contract + chat panel.

## Out of scope
- Persistent accounts / cloud saves / leaderboards (no persistence requested).
- Server-authoritative anti-cheat netcode (multiplayer is client-authoritative friends-play).
