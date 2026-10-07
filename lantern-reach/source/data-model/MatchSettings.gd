extends Resource

enum Visibility { PER_PLAYER, ALL_PLAYERS, FULL }

@export var players: Array[Resource] = []
@export var visibility = Visibility.PER_PLAYER
@export var visible_player = 0

# Lantern Reach: the world this match is played on.
@export var terrain = "grassland"  # a key of Terrains.PRESETS
@export var world_id = ""  # Campaign world id, "" for a skirmish
@export var hollow_nests = 0  # nests the Hollow player starts with (needs a HOLLOW player)
# {"type": "destroy_all" | "survive" | "harvest" | "nests", "amount": int} ("" = destroy all)
@export var objective = {}
@export var difficulty = 1.0  # scales Hollow wave size and pace
