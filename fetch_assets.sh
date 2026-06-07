#!/usr/bin/env bash
# Re-download Emberhold's CC0 art (KayKit characters + props) and textures, and
# regenerate the procedural audio. The binaries are git-ignored to keep the repo
# lean; run this once after cloning, then open the project in Godot 4.6.3.
set -euo pipefail
cd "$(dirname "$0")"

ASSETS="https://preview.myapping.com/godot-assets"
TEX="https://preview.myapping.com/godot-textures"
mkdir -p models/props textures

chars=(kk_Knight kk_Mage kk_Rogue kk_Skeleton_Minion kk_Skeleton_Warrior kk_Skeleton_Rogue)
for c in "${chars[@]}"; do
  curl -sfL "$ASSETS/characters/$c.glb" -o "models/$c.glb" && echo "ok $c"
done

# props (path on server -> flat models/props/<name>.glb)
props=(
  kk_hex/building_blacksmith_blue kk_hex/building_tavern_blue kk_hex/building_market_blue
  kk_hex/building_home_B_blue kk_hex/building_well_blue kk_hex/building_church_blue
  kk_hex/building_tower_B_blue kk_dungeon/banner_patternA_red kk_dungeon/banner_blue
  kk_rpgtools/anvil kk_rpgtools/lantern kk_food/crate kk_resource/Fuel_A_Barrel
  kk_resource/Gold_Bars_Stack_Large kk_nature/Bush_1_A_Color1 kk_nature/Bush_2_B_Color1
  kk_weapons/shield_B kk_weapons/axe_A kk_weapons/axe_C kk_weapons/hammer_C
  kk_weapons/spear_A kk_weapons/bow_A kk_weapons/arrow_A kk_weapons/dagger_B
)
for p in "${props[@]}"; do
  curl -sfL "$ASSETS/props/$p.glb" -o "models/props/$(basename "$p").glb" && echo "ok $(basename "$p")"
done

for t in grass stone_floor brick_wall dirt_ground; do
  curl -sfL "$TEX/$t.png" -o "textures/$t.png" && echo "ok $t.png"
done

python3 tools/gen_audio.py
echo "Assets ready. Open the project in Godot 4.6.3 (it will import on first launch)."
