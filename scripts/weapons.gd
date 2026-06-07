class_name Weapons
extends RefCounted
## The hero arsenal. Each entry is a self-contained weapon definition: which KayKit
## models attach to which hands, the light-combo + heavy clip names (all verified to
## exist on the Rig_Medium AnimationPlayer), and the feel knobs (damage, reach, arc,
## cadence, screen-shake, and — for ranged weapons — a real traveling projectile).
## Shared across every hero; the hero pick just sets the STARTING weapon.

const LIST: Array = [
	{
		"id": "axe",
		"label": "AXE+SHIELD",
		"icon": "[X]",
		"rhand": "res://models/props/axe_A.glb",
		"lhand": "res://models/props/shield_B.glb",
		"light": ["Melee_1H_Attack_Slice_Horizontal", "Melee_1H_Attack_Slice_Diagonal", "Melee_1H_Attack_Chop"],
		"heavy": "Melee_1H_Attack_Stab",
		"light_dmg": 22.0,
		"heavy_dmg": 42.0,
		"range": 3.1,
		"arc": 0.2,
		"heavy_arc": 0.05,
		"light_cd": 0.42,
		"heavy_cd": 0.95,
		"speed": 1.35,
		"swing_at": 0.2,
		"ranged": false,
		"spell": false,
		"shake": 0.18,
		"heavy_shake": 0.36,
		"proj_color": Color(1, 1, 1),
		"proj_speed": 0.0,
	},
	{
		"id": "hammer",
		"label": "WARHAMMER",
		"icon": "[#]",
		"rhand": "res://models/props/hammer_C.glb",
		"lhand": "",
		"light": ["Melee_2H_Attack_Chop", "Melee_2H_Attack_Slice"],
		"heavy": "Melee_2H_Attack_Spinning",
		"light_dmg": 34.0,
		"heavy_dmg": 62.0,
		"range": 3.5,
		"arc": 0.0,
		"heavy_arc": -1.0,
		"light_cd": 0.8,
		"heavy_cd": 1.55,
		"speed": 1.05,
		"swing_at": 0.34,
		"ranged": false,
		"spell": false,
		"shake": 0.32,
		"heavy_shake": 0.6,
		"proj_color": Color(1, 1, 1),
		"proj_speed": 0.0,
	},
	{
		"id": "spear",
		"label": "WAR SPEAR",
		"icon": "[/]",
		"rhand": "res://models/props/spear_A.glb",
		"lhand": "",
		"light": ["Melee_2H_Attack_Stab"],
		"heavy": "Melee_2H_Attack_Slice",
		"light_dmg": 24.0,
		"heavy_dmg": 44.0,
		"range": 4.7,
		"arc": 0.55,
		"heavy_arc": 0.1,
		"light_cd": 0.55,
		"heavy_cd": 1.05,
		"speed": 1.25,
		"swing_at": 0.22,
		"ranged": false,
		"spell": false,
		"shake": 0.2,
		"heavy_shake": 0.4,
		"proj_color": Color(1, 1, 1),
		"proj_speed": 0.0,
	},
	{
		"id": "bow",
		"label": "LONGBOW",
		"icon": "[)]",
		"rhand": "",
		"lhand": "res://models/props/bow_A.glb",
		"light": ["Ranged_Bow_Release"],
		"heavy": "Ranged_Bow_Release_Up",
		"light_dmg": 17.0,
		"heavy_dmg": 34.0,
		"range": 30.0,
		"arc": 0.0,
		"heavy_arc": 0.0,
		"light_cd": 0.5,
		"heavy_cd": 1.1,
		"speed": 1.5,
		"swing_at": 0.18,
		"ranged": true,
		"spell": false,
		"shake": 0.08,
		"heavy_shake": 0.2,
		"proj_color": Color(1.0, 0.85, 0.4),
		"proj_speed": 38.0,
	},
	{
		"id": "arcane",
		"label": "ARCANE",
		"icon": "[*]",
		"rhand": "",
		"lhand": "",
		"light": ["Ranged_Magic_Shoot"],
		"heavy": "Ranged_Magic_Spellcasting_Long",
		"light_dmg": 20.0,
		"heavy_dmg": 40.0,
		"range": 24.0,
		"arc": 0.0,
		"heavy_arc": 0.0,
		"light_cd": 0.55,
		"heavy_cd": 1.3,
		"speed": 1.2,
		"swing_at": 0.3,
		"ranged": true,
		"spell": true,
		"shake": 0.1,
		"heavy_shake": 0.26,
		"proj_color": Color(0.7, 0.45, 1.0),
		"proj_speed": 28.0,
	},
]


static func count() -> int:
	return LIST.size()


static func get_def(i: int) -> Dictionary:
	return LIST[posmod(i, LIST.size())]


static func start_for(hero: String) -> int:
	match hero:
		"mage":
			return 4
		"rogue":
			return 3
		_:
			return 0
