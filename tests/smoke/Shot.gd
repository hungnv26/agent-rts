extends SceneTree

# Renders any scene to a PNG after a number of frames (needs a display; use xvfb-run):
#   godot --path . --script res://tests/smoke/Shot.gd -- --scene=res://source/main-menu/Campaign.tscn --out=/tmp/campaign.png

var _scene_path = "res://source/Main.tscn"
var _out = "shot.png"
var _frames = 30
var _elapsed = 0


func _init():
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--scene="):
			_scene_path = arg.substr(8)
		elif arg.begins_with("--out="):
			_out = arg.substr(6)
		elif arg.begins_with("--frames="):
			_frames = int(arg.substr(9))


func _process(_delta):
	if _elapsed == 0:
		var scene = load(_scene_path).instantiate()
		root.add_child(scene)
		current_scene = scene
	_elapsed += 1
	if _elapsed == _frames:
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(_out)
		print("shot: saved ", _out)
		quit()
	return false
