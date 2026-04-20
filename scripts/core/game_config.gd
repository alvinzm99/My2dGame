class_name GameConfig
extends RefCounted

const MAP_HALF_SIZE := Vector2(1800.0, 1200.0)
const CAMP_RADIUS := 560.0
const DAY_SECONDS := 38.0
const NIGHT_SECONDS := 45.0
const SURVIVOR_SPEED := 135.0
const ZOMBIE_SPEED := 72.0
const INTERACT_RANGE := 36.0
const BUILD_GRID := 48.0
const CLICK_DRAG_THRESHOLD := 8.0
const SURVIVOR_RANGED_RANGE := 245.0
const SURVIVOR_MELEE_RANGE := 58.0
const SURVIVOR_BOW_DAMAGE := 10.0
const SURVIVOR_MELEE_DAMAGE := 16.0
const SURVIVOR_BOW_COOLDOWN := 0.9
const SURVIVOR_MELEE_COOLDOWN := 0.55
const MANUAL_COMMAND_GRACE := 2.5
const SURVIVOR_REPAIR_RANGE := 52.0
const SURVIVOR_REPAIR_AMOUNT := 18.0
const STARTING_WALL_RADIUS := 250.0
const DAY_ROAMER_MIN_DISTANCE := 920.0
const DAY_CAMP_AGGRO_DISTANCE := 190.0
const DAY_BUILDING_AGGRO_DISTANCE := 120.0
const DAY_SURVIVOR_AGGRO_DISTANCE := 170.0

const RESOURCE_COLORS := {
	"wood": Color("#5d8a45"),
	"scrap": Color("#8a9299"),
	"food": Color("#d6a03f"),
}

const BUILDINGS := {
	"wall": {
		"name": "Wall",
		"cost": {"wood": 12, "scrap": 4},
		"hp": 180,
		"size": Vector2(42, 42),
		"color": Color("#6b7075"),
	},
	"tower": {
		"name": "Watchtower",
		"cost": {"wood": 24, "scrap": 18},
		"hp": 140,
		"size": Vector2(46, 46),
		"color": Color("#a26d3d"),
		"range": 280.0,
		"damage": 18.0,
		"cooldown": 0.7,
	},
	"shelter": {
		"name": "Shelter",
		"cost": {"wood": 32, "food": 18},
		"hp": 220,
		"size": Vector2(66, 48),
		"color": Color("#546e7a"),
	},
}

const REGIONS := [
	{
		"name": "旧高速服务区",
		"resource_goal": {"wood": 120, "scrap": 70, "food": 55},
		"required_nights": 2,
		"required_buildings": {"wall": 4, "tower": 1, "shelter": 1},
		"threat": 1,
	},
	{
		"name": "废弃工业镇",
		"resource_goal": {"wood": 180, "scrap": 135, "food": 90},
		"required_nights": 3,
		"required_buildings": {"wall": 7, "tower": 2, "shelter": 2},
		"threat": 2,
	},
	{
		"name": "河岸隔离带",
		"resource_goal": {"wood": 260, "scrap": 210, "food": 135},
		"required_nights": 4,
		"required_buildings": {"wall": 10, "tower": 3, "shelter": 3},
		"threat": 3,
	},
]
