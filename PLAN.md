# Plan — mobile UI polish + weapon arsenal

Follow-up round on Emberhold. Four asks: (1) bigger, mobile-friendly NPC chat/typing UI,
(2) bigger, less-congested top-right buttons, (3) better click/press animation on those buttons,
(4) give the hero better weapons + more attack options.

## Goal
- **NPC chat:** redesign as a large, touch-first sheet. Input field moved to the TOP of the panel
  (right under the title) so the on-screen keyboard never hides it; big LineEdit + SEND, large chat
  log font, quick-reply chips that wrap to a grid with big touch targets.
- **Top-right HUD:** replace the lone cramped mute button with a clean, well-spaced cluster of big
  pill buttons (SOUND toggle + SHARE) and a readable room-code pill; remove the old congested layout.
- **Button press juice:** reusable press animation (scale punch with BACK/elastic ease + brightness
  pop) bound to the button node; applied to the top-right cluster AND the combat buttons.
- **Weapons + attacks:** a real arsenal the hero cycles through with a WEAPON-swap button, plus a
  LIGHT (combo) and a HEAVY/SPECIAL attack button. Each weapon has its own KayKit model(s), attack
  animation set, damage, range, arc, cooldown, and feel. Ranged weapons (bow, magic) fire a real
  traveling projectile that sparks on hit.

## Files to touch
- `main.gd` — rebuild chat UI (input-on-top, big), rebuild top-right HUD cluster, add press-juice
  helper, add SPECIAL + WEAPON buttons, weapon-swap + heavy-attack wiring, projectile spawn/step,
  shared `_damage_target` helper, virtual-keyboard nudge for the chat panel.
- `scripts/weapons.gd` (new) — `Weapons` data: arsenal list + per-weapon def (models, light combo,
  heavy clip, dmg, range, arc, cooldown, speed, ranged/spell flags, projectile color).
- `scripts/player.gd` — equip/cycle weapon, attach right-hand + off-hand models, light/heavy attack
  with combo index, emit ranged-fire signal, expose equipped weapon in `net_state`.
- `scripts/projectile.gd` (new) — travels forward, detects skeletons/remote players, emits `struck`.
- `scripts/rig.gd` — `play_clip(name, speed)` passthrough + swap-weapon attach/detach support.
- `scripts/remote_player.gd` — reflect peer's equipped weapon model + relayed attack clip.
- `scripts/skeleton.gd` — add to group `skeletons` so projectiles can hit them.
- `fetch_assets.sh` — add the new weapon GLBs (axe_C, hammer_A, dagger_B, spear_A, bow_A, arrow_A).
- `export_presets.cfg` — keep nothreads/Compatibility; no functional change expected.
- `README.md` — document the arsenal + new controls.

## Verification approach
- Headless export (nothreads/Compatibility) must succeed; `out/` has index.{html,js,wasm,pck}.
- Clip-resolution check: every attack clip name referenced exists in the KayKit AnimationPlayer.
- Playwright smoke (our verifier): engine boots, canvas, clean console, frames captured.
- Targeted: drive WEAPON-swap then LIGHT + HEAVY attack on a spawned skeleton, assert hp drops via
  the real damage path AND a spark/flash is emitted (JUICE FLOOR); confirm projectile travels for
  ranged weapons. Drive facing (W away / S toward camera) to confirm no +Z moonwalk regression.
- Multiplayer transport unaffected (2-client loopback still delivers); connect-path marker still set.
- Screenshot-critique the chat sheet + top-right cluster for size/legibility on the portrait canvas.

## Out of scope
- No backend/Supabase schema changes (no new persistence). Realtime netcode unchanged except adding
  the equipped-weapon field + attack-clip to existing state/act packets.
- No new hero models; arsenal is shared across heroes (hero pick just sets the starting weapon).
- Locomotion/AI tuning, new zones, loot economy — not requested.
