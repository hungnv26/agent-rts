extends Node

# The ten worlds of the Reach, in order, and which of them the player has relit. Autoloaded.
# A world is a match: a map, a terrain, who else is on it (Wardens, Hollow nests), and what
# counts as winning. Progress is saved in user://.

const MatchSettings = preload("res://source/data-model/MatchSettings.gd")
const PlayerSettings = preload("res://source/data-model/PlayerSettings.gd")

const SAVE_PATH = "user://lantern_reach_campaign.cfg"
const PLAIN = "res://source/match/maps/PlainAndSimple.tscn"
const WIDE = "res://source/match/maps/BigArena.tscn"

# objective: destroy_all | survive (amount = seconds) | harvest (amount = Lumen) | nests
const WORLDS = [
	{
		"id": "landing",
		"name": "Landing Site",
		"terrain": "grassland",
		"map": PLAIN,
		"wardens": 0,
		"nests": 1,
		"difficulty": 0.6,
		"objective": {"type": "harvest", "amount": 60},
		"intro": "Pod Seven is down in one piece, on the only green world in the Reach. The Lantern Core still burns. Put Engineers on the crystal: Lumen builds, Ember fights. One Hollow nest sleeps past the ridge. It will not sleep for long.",
		"outro": "Sixty Lumen in the hold and the Core burning steady. The Commander logs the first entry of the Chronicle: 'We are here. We are not alone.'",
	},
	{
		"id": "basin",
		"name": "Dust Basin",
		"terrain": "sahara",
		"map": PLAIN,
		"wardens": 0,
		"nests": 2,
		"difficulty": 0.8,
		"objective": {"type": "survive", "amount": 480},
		"intro": "Pod Three's beacon led here, to a basin of rust and glass. The pod is a crater. Two nests have grown on its wreck. Dig in: Cannon Posts for the ground, Flak Posts for the sky, Troopers for both. Hold until the relay finishes its burst.",
		"outro": "The relay burst goes out at dawn. Somewhere, Fleet hears it. Somewhere closer, so does the Hollow.",
	},
	{
		"id": "frost",
		"name": "Frost Line",
		"terrain": "arctic",
		"map": PLAIN,
		"wardens": 0,
		"nests": 2,
		"difficulty": 1.0,
		"objective": {"type": "nests", "amount": 0},
		"intro": "Ice to every horizon and a signal under it: Pod Five, alive, sealed in. The Hollow nests between you and them. Burn out every nest. Tanks break nests fastest; keep Troopers close, the motes come at night.",
		"outro": "Pod Five's hatch opens into the cold. Twelve survivors, and a warning: 'Pod One is still out there. They are not going to be glad to see you.'",
	},
	{
		"id": "shore",
		"name": "Shoreline",
		"terrain": "beach",
		"map": PLAIN,
		"wardens": 1,
		"nests": 1,
		"difficulty": 1.0,
		"objective": {"type": "destroy_all", "amount": 0},
		"intro": "A warm sea and a warm welcome: cannon fire. Pod One's crew call themselves the Wardens now. They believe every lantern lit calls the Hollow down on all of them, and they have decided to put yours out. Take their base apart. The nest on the far shore will not pick a side.",
		"outro": "The Wardens' outpost is ash. Their last transmission is not a surrender: 'You have no idea what you are waking up.'",
	},
	{
		"id": "rift",
		"name": "The Rift",
		"terrain": "canyon",
		"map": PLAIN,
		"wardens": 0,
		"nests": 3,
		"difficulty": 1.2,
		"objective": {"type": "survive", "amount": 600},
		"intro": "Red stone walls and three nests in the dark between them. The Analyst needs ten minutes of readings from the canyon floor. Every minute the Hollow comes harder. Build before you are rich: a Solar Array keeps Lumen trickling when the Engineers are pinned down.",
		"outro": "The readings are in. The Hollow is not spreading at random. Every nest in the Reach points the same way.",
	},
	{
		"id": "red",
		"name": "Red Reach",
		"terrain": "mars",
		"map": PLAIN,
		"wardens": 0,
		"nests": 3,
		"difficulty": 1.3,
		"objective": {"type": "nests", "amount": 0},
		"intro": "The nests point here. Under the red dust lies the hull of the Lantern itself, and the Hollow has grown through it. Burn out the nests over the hull. Gunships cross the dunes fastest; the Brutes cannot touch them.",
		"outro": "With the nests gone, the hull is quiet enough to read. The ship's log ends with the first Director's voice: 'The Hollow is not from the Reach. It came with us.'",
	},
	{
		"id": "dark",
		"name": "Dark Side",
		"terrain": "moon",
		"map": WIDE,
		"wardens": 2,
		"nests": 2,
		"difficulty": 1.3,
		"objective": {"type": "destroy_all", "amount": 0},
		"intro": "No air, no light, and two Warden strongholds that read the same log you did. They want the Lantern's core dark forever. You want it lit. Scout Drones see in the night here; nothing else does.",
		"outro": "The Wardens' fleet is gone. In the wreckage, their Director's final order: 'If they light it, let it be on their heads.'",
	},
	{
		"id": "acid",
		"name": "Acid Sky",
		"terrain": "venus",
		"map": PLAIN,
		"wardens": 0,
		"nests": 3,
		"difficulty": 1.5,
		"objective": {"type": "harvest", "amount": 220},
		"intro": "Relighting the Lantern's core takes more Lumen than one world holds. Venus holds it, under a sky that eats metal. Mine two hundred and twenty Lumen while three nests wake. Engineers are the objective now; keep them alive.",
		"outro": "The hold is full. The Writer closes the Chronicle's ninth chapter with one line: 'Two worlds left, and one of them is the one we fell from.'",
	},
	{
		"id": "ice",
		"name": "Ice Moon",
		"terrain": "europa",
		"map": WIDE,
		"wardens": 0,
		"nests": 4,
		"difficulty": 1.6,
		"objective": {"type": "survive", "amount": 720},
		"intro": "Europa's crystal field is the brightest thing in the Reach, which is why the Hollow has four nests on it. Hold the field for twelve minutes while the Coder cuts the core free. Build wide: Flak Posts at every approach, Tanks in the gaps.",
		"outro": "The core lifts out of the ice on a Hangar crane, dark and whole. One world left.",
	},
	{
		"id": "far",
		"name": "Far Shore",
		"terrain": "titan",
		"map": WIDE,
		"wardens": 3,
		"nests": 4,
		"difficulty": 1.8,
		"objective": {"type": "destroy_all", "amount": 0},
		"intro": "Titan. The Lantern's launch pad, the last Warden strongholds, and every nest the Hollow has left. Light the core here and Fleet will come, and so will whatever followed the Lantern across the dark. The Reviewer asks the question one more time. You answer by winning.",
		"outro": "The core burns on the pad. The Reach is lit from end to end. The Chronicle ends: 'We lit it. Whatever comes next comes to a people who held ten worlds. Let it come.'",
	},
]

var completed = {}


func _ready():
	_load()


func world_count():
	return WORLDS.size()


func world(index: int):
	return WORLDS[index]


func index_of(world_id: String):
	for i in range(WORLDS.size()):
		if WORLDS[i]["id"] == world_id:
			return i
	return -1


func is_unlocked(index: int):
	return index == 0 or completed.has(WORLDS[index - 1]["id"])


func is_completed(index: int):
	return completed.has(WORLDS[index]["id"])


func complete_world(world_id: String):
	if world_id == "" or completed.has(world_id):
		return
	completed[world_id] = true
	_save()


func reset():
	completed = {}
	_save()


func objective_text(objective: Dictionary):
	match objective.get("type", "destroy_all"):
		"survive":
			return tr("OBJECTIVE_SURVIVE") + " " + _mmss(objective["amount"])
		"harvest":
			return tr("OBJECTIVE_HARVEST") + " " + str(objective["amount"])
		"nests":
			return tr("OBJECTIVE_NESTS")
	return tr("OBJECTIVE_DESTROY_ALL")


# Match settings for a world: the player in the first spawn, Wardens next, the Hollow in the
# spawn after them (so it lands as far from the player as the map allows), extra nests on
# whatever spawn points are left.
func build_match_settings(index: int):
	var w = WORLDS[index]
	var settings = MatchSettings.new()
	var human = PlayerSettings.new()
	human.controller = Constants.PlayerType.HUMAN
	human.color = Constants.Player.COLORS[0]
	settings.players.append(human)
	for i in range(w["wardens"]):
		var warden = PlayerSettings.new()
		warden.controller = Constants.PlayerType.SIMPLE_CLAIRVOYANT_AI
		warden.color = Constants.Player.COLORS[1 + i]
		settings.players.append(warden)
	if w["nests"] > 0:
		var map_players = Constants.Match.MAPS[w["map"]]["players"]
		var hollow = PlayerSettings.new()
		hollow.controller = Constants.PlayerType.HOLLOW
		hollow.color = Constants.Player.HOLLOW_COLOR
		# skip ahead to the spawn opposite the player when the map has room
		var used = 1 + w["wardens"]
		var wanted = map_players / 2
		hollow.spawn_index_offset = max(0, wanted - used)
		settings.players.append(hollow)
	settings.visible_player = 0
	settings.terrain = w["terrain"]
	settings.world_id = w["id"]
	settings.hollow_nests = w["nests"]
	settings.objective = w["objective"]
	settings.difficulty = w["difficulty"]
	return settings


func _mmss(seconds: int):
	return "%d:%02d" % [seconds / 60, seconds % 60]


func _save():
	var config = ConfigFile.new()
	for id in completed:
		config.set_value("completed", id, true)
	config.save(SAVE_PATH)


func _load():
	var config = ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return
	if config.has_section("completed"):
		for id in config.get_section_keys("completed"):
			completed[id] = true
