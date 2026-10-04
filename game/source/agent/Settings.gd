extends RefCounted

# Player display settings, saved to user://agent_rts_settings.cfg.
#   window: windowed/fullscreen and window size (in screen points, so presets mean the same
#           on Retina/5K displays as on a 1080p monitor)
#   render_scale: 3D render resolution (0.5..1.0), UI and labels always stay sharp
#   msaa: 3D anti-aliasing (0 off, 1 = 2x, 2 = 4x)
#   ui_size: HUD/label size relative to the automatic size for this window
#   zoom: map zoom (camera size; smaller = closer)

const PATH = "user://agent_rts_settings.cfg"
const WINDOW_SIZES = [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080), Vector2i(2560, 1440)]
const RENDER_SCALES = [0.5, 0.67, 0.75, 1.0]
const UI_SIZES = [0.8, 1.0, 1.25, 1.5]
const ZOOM_MIN = 12.0
const ZOOM_MAX = 42.0
const ZOOM_DEFAULT = 29.0

var fullscreen = false
var window_size = Vector2i(1600, 900)
var render_scale = 1.0
var msaa = 1
var ui_size = 1.0
var zoom = ZOOM_DEFAULT
var has_saved_window = false


func load_settings():
	var cfg = ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	fullscreen = cfg.get_value("display", "fullscreen", fullscreen)
	window_size = cfg.get_value("display", "window_size", window_size)
	has_saved_window = cfg.has_section_key("display", "window_size")
	render_scale = cfg.get_value("display", "render_scale", render_scale)
	msaa = cfg.get_value("display", "msaa", msaa)
	ui_size = cfg.get_value("display", "ui_size", ui_size)
	zoom = cfg.get_value("map", "zoom", zoom)


func save_settings():
	var cfg = ConfigFile.new()
	cfg.set_value("display", "fullscreen", fullscreen)
	cfg.set_value("display", "window_size", window_size)
	cfg.set_value("display", "render_scale", render_scale)
	cfg.set_value("display", "msaa", msaa)
	cfg.set_value("display", "ui_size", ui_size)
	cfg.set_value("map", "zoom", zoom)
	cfg.save(PATH)


func apply_window():
	if DisplayServer.get_name() == "headless":
		return
	if fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		return
	if DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_WINDOWED:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	var screen = DisplayServer.window_get_current_screen()
	var scale = DisplayServer.screen_get_scale(screen)
	var px = Vector2i(Vector2(window_size) * scale)
	var usable = DisplayServer.screen_get_usable_rect(screen)
	px = px.min(usable.size)
	DisplayServer.window_set_size(px)
	DisplayServer.window_set_position(usable.position + (usable.size - px) / 2)


func apply_render(viewport: Viewport):
	viewport.scaling_3d_scale = render_scale
	viewport.msaa_3d = [Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X][clampi(msaa, 0, 2)]


func clamp_zoom(value: float) -> float:
	return clampf(value, ZOOM_MIN, ZOOM_MAX)
