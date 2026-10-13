const OWNED_PLAYER_CIRCLE_COLOR = Color.GREEN
const ADVERSARY_PLAYER_CIRCLE_COLOR = Color.RED
const RESOURCE_CIRCLE_COLOR = Color.YELLOW
const DEFAULT_CIRCLE_COLOR = Color.WHITE
const MAPS = {
	"res://source/match/maps/PlainAndSimple.tscn":
	{
		"name": "Lantern Plain",
		"players": 4,
		"size": Vector2i(50, 50),
	},
	"res://source/match/maps/BigArena.tscn":
	{
		"name": "Wide Reach",
		"players": 8,
		"size": Vector2i(100, 100),
	},
}


class Navigation:
	enum Domain { AIR, TERRAIN }

	const DOMAIN_TO_GROUP_MAPPING = {
		Domain.AIR: "air_navigation_input",
		Domain.TERRAIN: "terrain_navigation_input",
	}


class Air:
	const Y = 1.5
	const PLANE = Plane(Vector3.UP, Y)

	class Navmesh:
		const CELL_SIZE = 0.4
		const CELL_HEIGHT = 0.4
		const MAX_AGENT_RADIUS = 0.8


class Terrain:
	const PLANE = Plane(Vector3.UP, 0)

	class Navmesh:
		const CELL_SIZE = 0.3
		const CELL_HEIGHT = 0.3
		const MAX_AGENT_RADIUS = 0.9  # max radius of movable units


# Lumen (blue crystal, resource_a) powers computation and construction; Ember (red crystal,
# resource_b) powers engines and weapons. Lumen is quick to mine, Ember slow.
class Resources:
	class A:
		const COLOR = Color.BLUE
		const MATERIAL_PATH = "res://source/match/resources/materials/resource_a.material.tres"
		const COLLECTING_TIME_S = 1.0

	class B:
		const COLOR = Color.RED
		const MATERIAL_PATH = "res://source/match/resources/materials/resource_b.material.tres"
		const COLLECTING_TIME_S = 2.0


class Units:
	const U = "res://source/match/units/"

	# Pod Seven's roster. Scene file names are the Open RTS originals; the names the player
	# sees are in assets/translations/match.csv (Worker = Engineer, Helicopter = Gunship,
	# CommandCenter = Lantern Core, ...).
	const PRODUCTION_COSTS = {
		U + "Worker.tscn": {"resource_a": 2, "resource_b": 0},
		U + "Drone.tscn": {"resource_a": 2, "resource_b": 0},
		U + "Trooper.tscn": {"resource_a": 2, "resource_b": 1},
		U + "Tank.tscn": {"resource_a": 3, "resource_b": 2},
		U + "Helicopter.tscn": {"resource_a": 1, "resource_b": 3},
	}
	const PRODUCTION_TIMES = {
		U + "Worker.tscn": 3.0,
		U + "Drone.tscn": 3.0,
		U + "Trooper.tscn": 4.0,
		U + "Tank.tscn": 6.0,
		U + "Helicopter.tscn": 6.0,
	}
	const PRODUCTION_QUEUE_LIMIT = 5
	const STRUCTURE_BLUEPRINTS = {
		U + "CommandCenter.tscn": U + "structure-geometries/CommandCenter.tscn",
		U + "VehicleFactory.tscn": U + "structure-geometries/VehicleFactory.tscn",
		U + "AircraftFactory.tscn": U + "structure-geometries/AircraftFactory.tscn",
		U + "MechForge.tscn": U + "structure-geometries/MechForge.tscn",
		U + "SolarArray.tscn": U + "structure-geometries/SolarArray.tscn",
		U + "AntiGroundTurret.tscn": U + "structure-geometries/AntiGroundTurret.tscn",
		U + "AntiAirTurret.tscn": U + "structure-geometries/AntiAirTurret.tscn",
	}
	const CONSTRUCTION_COSTS = {
		U + "CommandCenter.tscn": {"resource_a": 8, "resource_b": 8},
		U + "VehicleFactory.tscn": {"resource_a": 6, "resource_b": 0},
		U + "AircraftFactory.tscn": {"resource_a": 4, "resource_b": 4},
		U + "MechForge.tscn": {"resource_a": 4, "resource_b": 2},
		U + "SolarArray.tscn": {"resource_a": 3, "resource_b": 0},
		U + "AntiGroundTurret.tscn": {"resource_a": 2, "resource_b": 2},
		U + "AntiAirTurret.tscn": {"resource_a": 2, "resource_b": 2},
	}
	const DEFAULT_PROPERTIES = {
		# ---- Pod Seven ----
		U + "Worker.tscn":
		{
			"sight_range": 5.0,
			"hp": 6,
			"hp_max": 6,
			"resources_max": 2,
		},
		U + "Drone.tscn":
		{
			"sight_range": 12.0,
			"hp": 6,
			"hp_max": 6,
		},
		U + "Trooper.tscn":
		{
			"sight_range": 8.0,
			"hp": 8,
			"hp_max": 8,
			"attack_damage": 1,
			"attack_interval": 0.6,
			"attack_range": 4.0,
			"attack_domains": [Navigation.Domain.TERRAIN, Navigation.Domain.AIR],
		},
		U + "Tank.tscn":
		{
			"sight_range": 8.0,
			"hp": 12,
			"hp_max": 12,
			"attack_damage": 2,
			"attack_interval": 0.75,
			"attack_range": 5.0,
			"attack_domains": [Navigation.Domain.TERRAIN],
		},
		U + "Helicopter.tscn":
		{
			"sight_range": 8.0,
			"hp": 10,
			"hp_max": 10,
			"attack_damage": 1,
			"attack_interval": 1.0,
			"attack_range": 5.0,
			"attack_domains": [Navigation.Domain.TERRAIN, Navigation.Domain.AIR],
		},
		U + "CommandCenter.tscn":
		{
			"sight_range": 10.0,
			"hp": 30,
			"hp_max": 30,
		},
		U + "VehicleFactory.tscn":
		{
			"sight_range": 8.0,
			"hp": 16,
			"hp_max": 16,
		},
		U + "AircraftFactory.tscn":
		{
			"sight_range": 8.0,
			"hp": 16,
			"hp_max": 16,
		},
		U + "MechForge.tscn":
		{
			"sight_range": 8.0,
			"hp": 16,
			"hp_max": 16,
		},
		U + "SolarArray.tscn":
		{
			"sight_range": 6.0,
			"hp": 8,
			"hp_max": 8,
		},
		U + "AntiGroundTurret.tscn":
		{
			"sight_range": 8.0,
			"hp": 8,
			"hp_max": 8,
			"attack_damage": 2,
			"attack_interval": 1.0,
			"attack_range": 8.0,
			"attack_domains": [Navigation.Domain.TERRAIN],
		},
		U + "AntiAirTurret.tscn":
		{
			"sight_range": 8.0,
			"hp": 8,
			"hp_max": 8,
			"attack_damage": 2,
			"attack_interval": 0.75,
			"attack_range": 8.0,
			"attack_domains": [Navigation.Domain.AIR],
		},
		# ---- The Hollow (never built; spawned by nests) ----
		U + "HollowMote.tscn":
		{
			"sight_range": 9.0,
			"hp": 4,
			"hp_max": 4,
			"attack_damage": 1,
			"attack_interval": 1.0,
			"attack_range": 1.6,
			"attack_domains": [Navigation.Domain.TERRAIN, Navigation.Domain.AIR],
		},
		U + "HollowBrute.tscn":
		{
			"sight_range": 8.0,
			"hp": 14,
			"hp_max": 14,
			"attack_damage": 2,
			"attack_interval": 1.5,
			"attack_range": 1.8,
			"attack_domains": [Navigation.Domain.TERRAIN],
		},
		U + "HollowWasp.tscn":
		{
			"sight_range": 10.0,
			"hp": 6,
			"hp_max": 6,
			"attack_damage": 1,
			"attack_interval": 0.8,
			"attack_range": 1.6,
			"attack_domains": [Navigation.Domain.TERRAIN, Navigation.Domain.AIR],
		},
		U + "HollowNest.tscn":
		{
			"sight_range": 8.0,
			"hp": 30,
			"hp_max": 30,
		},
	}
	const PROJECTILES = {
		U + "Helicopter.tscn": U + "projectiles/Rocket.tscn",
		U + "Tank.tscn": U + "projectiles/CannonShell.tscn",
		U + "Trooper.tscn": U + "projectiles/CannonShell.tscn",
		U + "AntiGroundTurret.tscn": U + "projectiles/CannonShell.tscn",
		U + "AntiAirTurret.tscn": U + "projectiles/Rocket.tscn",
		U + "HollowMote.tscn": U + "projectiles/HollowBite.tscn",
		U + "HollowBrute.tscn": U + "projectiles/HollowBite.tscn",
		U + "HollowWasp.tscn": U + "projectiles/HollowBite.tscn",
	}
	# Scenes that are not in the cost tables but still need preloading before a match.
	const EXTRA_PRELOADS = [
		U + "Trooper.tscn",
		U + "HollowMote.tscn",
		U + "HollowBrute.tscn",
		U + "HollowWasp.tscn",
		U + "HollowNest.tscn",
	]
	const ADHERENCE_MARGIN_M = 0.3  # TODO: try lowering while fixing a 'push' problem
	const NEW_RESOURCE_SEARCH_RADIUS_M = 30
	const MOVING_UNIT_RADIUS_MAX_M = 1.0
	const EMPTY_SPACE_RADIUS_SURROUNDING_STRUCTURE_M = MOVING_UNIT_RADIUS_MAX_M * 2.5
	const STRUCTURE_CONSTRUCTING_SPEED = 0.3  # progress [0.0..1.0] per second
	# A Solar Array adds this much Lumen every SOLAR_ARRAY_TICK_S of daylight.
	const SOLAR_ARRAY_LUMEN_PER_TICK = 1
	const SOLAR_ARRAY_TICK_S = 8.0


# One day is DAY_LENGTH_S long; the last NIGHT_FRACTION of it is night. At night sight ranges
# shrink and the Hollow sends bigger waves.
class DayCycle:
	const DAY_LENGTH_S = 480.0
	const NIGHT_FRACTION = 0.3
	const NIGHT_SIGHT_FACTOR = 0.6


class VoiceNarrator:
	enum Events {
		MATCH_STARTED,
		MATCH_ABORTED,
		MATCH_FINISHED_WITH_VICTORY,
		MATCH_FINISHED_WITH_DEFEAT,
		BASE_UNDER_ATTACK,
		UNIT_UNDER_ATTACK,
		UNIT_LOST,
		UNIT_PRODUCTION_STARTED,
		UNIT_PRODUCTION_FINISHED,
		UNIT_CONSTRUCTION_FINISHED,
		UNIT_HELLO,
		UNIT_ACK_1,
		UNIT_ACK_2,
		NOT_ENOUGH_RESOURCES,
	}

	const EVENT_TO_ASSET_MAPPING = {
		Events.MATCH_STARTED:
		preload("res://assets/voice/english/ttsmaker-com-148-alayna-us/battle_control_online.ogg"),
		Events.MATCH_ABORTED:
		preload("res://assets/voice/english/ttsmaker-com-148-alayna-us/battle_control_offline.ogg"),
		Events.MATCH_FINISHED_WITH_VICTORY:
		preload("res://assets/voice/english/ttsmaker-com-148-alayna-us/you_are_victorious.ogg"),
		Events.MATCH_FINISHED_WITH_DEFEAT:
		preload("res://assets/voice/english/ttsmaker-com-148-alayna-us/you_have_lost.ogg"),
		Events.BASE_UNDER_ATTACK:
		preload(
			"res://assets/voice/english/ttsmaker-com-148-alayna-us/your_base_is_under_attack.ogg"
		),
		Events.UNIT_UNDER_ATTACK:
		preload("res://assets/voice/english/ttsmaker-com-148-alayna-us/unit_under_attack.ogg"),
		Events.UNIT_LOST:
		preload("res://assets/voice/english/ttsmaker-com-148-alayna-us/unit_lost.ogg"),
		Events.UNIT_PRODUCTION_STARTED:
		preload("res://assets/voice/english/ttsmaker-com-148-alayna-us/training.ogg"),
		Events.UNIT_PRODUCTION_FINISHED:
		preload("res://assets/voice/english/ttsmaker-com-148-alayna-us/unit_ready.ogg"),
		Events.UNIT_CONSTRUCTION_FINISHED:
		preload("res://assets/voice/english/ttsmaker-com-148-alayna-us/construction_complete.ogg"),
		Events.UNIT_HELLO:
		preload("res://assets/voice/english/ttsmaker-com-2704-jackson-us/sir.ogg"),
		Events.UNIT_ACK_1:
		preload("res://assets/voice/english/ttsmaker-com-2704-jackson-us/yes_sir.ogg"),
		Events.UNIT_ACK_2:
		preload("res://assets/voice/english/ttsmaker-com-2704-jackson-us/acknowledged.ogg"),
		Events.NOT_ENOUGH_RESOURCES:
		preload("res://assets/voice/english/ttsmaker-com-148-alayna-us/not_enough_resources.ogg"),
	}
